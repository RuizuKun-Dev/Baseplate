local CameraModule = {}

CameraModule.__index = CameraModule

local FFlagUserRemoveTheCameraApi

do
    local success, result = pcall(function()
        return UserSettings():IsUserFeatureEnabled('UserRemoveTheCameraApi')
    end)

    FFlagUserRemoveTheCameraApi = success and result
end

local FFlagUserFixCameraSelectModuleWarning

do
    local success, result = pcall(function()
        return UserSettings():IsUserFeatureEnabled('UserFixCameraSelectModuleWarning')
    end)

    FFlagUserFixCameraSelectModuleWarning = success and result
end

local FFlagUserFlagEnableNewVRSystem

do
    local success, result = pcall(function()
        return UserSettings():IsUserFeatureEnabled('UserFlagEnableNewVRSystem')
    end)

    FFlagUserFlagEnableNewVRSystem = success and result
end

local FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame

do
    local success, value = pcall(function()
        return UserSettings():IsUserFeatureEnabled(
[[UserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame]])
    end)

    FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame = success and value
end

local PLAYER_CAMERA_PROPERTIES = {
    'CameraMinZoomDistance',
    'CameraMaxZoomDistance',
    'CameraMode',
    'DevCameraOcclusionMode',
    'DevComputerCameraMode',
    'DevTouchCameraMode',
    'DevComputerMovementMode',
    'DevTouchMovementMode',
    'DevEnableMouseLock',
}
local USER_GAME_SETTINGS_PROPERTIES = {
    'ComputerCameraMovementMode',
    'ComputerMovementMode',
    'ControlMode',
    'GamepadCameraSensitivity',
    'MouseSensitivity',
    'RotationType',
    'TouchCameraMovementMode',
    'TouchMovementMode',
}
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local VRService = game:GetService('VRService')
local UserGameSettings = UserSettings():GetService('UserGameSettings')
local CameraUtils = require(script:WaitForChild('CameraUtils'))
local CameraInput = require(script:WaitForChild('CameraInput'))
local ClassicCamera = require(script:WaitForChild('ClassicCamera'))
local OrbitalCamera = require(script:WaitForChild('OrbitalCamera'))
local LegacyCamera = require(script:WaitForChild('LegacyCamera'))
local VehicleCamera = require(script:WaitForChild('VehicleCamera'))
local VRCamera = require(script:WaitForChild('VRCamera'))
local VRVehicleCamera = require(script:WaitForChild('VRVehicleCamera'))
local Invisicam = require(script:WaitForChild('Invisicam'))
local Poppercam = require(script:WaitForChild('Poppercam'))
local TransparencyController = require(script:WaitForChild('TransparencyController'))
local MouseLockController = require(script:WaitForChild('MouseLockController'))
local instantiatedCameraControllers = {}
local instantiatedOcclusionModules = {}

do
    local PlayerScripts = Players.LocalPlayer:WaitForChild('PlayerScripts')

    PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
    PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
    PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)
    PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
    PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Follow)
    PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Classic)
    PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.CameraToggle)
end

function CameraModule.new()
    local self = setmetatable({}, CameraModule)

    self.activeCameraController = nil
    self.activeOcclusionModule = nil
    self.activeTransparencyController = nil
    self.activeMouseLockController = nil
    self.currentComputerCameraMovementMode = nil
    self.cameraSubjectChangedConn = nil
    self.cameraTypeChangedConn = nil

    for _, player in pairs(Players:GetPlayers())do
        self:OnPlayerAdded(player)
    end

    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
    end)

    self.activeTransparencyController = TransparencyController.new()

    self.activeTransparencyController:Enable(true)

    if not UserInputService.TouchEnabled then
        self.activeMouseLockController = MouseLockController.new()

        local toggleEvent = self.activeMouseLockController:GetBindableToggleEvent()

        if toggleEvent then
            toggleEvent:Connect(function()
                self:OnMouseLockToggled()
            end)
        end
    end

    self:ActivateCameraController(self:GetCameraControlChoice())
    self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
    self:OnCurrentCameraChanged()
    RunService:BindToRenderStep('cameraRenderUpdate', Enum.RenderPriority.Camera.Value, function(
        dt
    )
        self:Update(dt)
    end)

    for _, propertyName in pairs(PLAYER_CAMERA_PROPERTIES)do
        Players.LocalPlayer:GetPropertyChangedSignal(propertyName):Connect(function(
        )
            self:OnLocalPlayerCameraPropertyChanged(propertyName)
        end)
    end
    for _, propertyName in pairs(USER_GAME_SETTINGS_PROPERTIES)do
        UserGameSettings:GetPropertyChangedSignal(propertyName):Connect(function(
        )
            self:OnUserGameSettingsPropertyChanged(propertyName)
        end)
    end

    game.Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
        self:OnCurrentCameraChanged()
    end)

    self.lastInputType = UserInputService:GetLastInputType()

    UserInputService.LastInputTypeChanged:Connect(function(newLastInputType)
        self.lastInputType = newLastInputType
    end)

    return self
end
function CameraModule:GetCameraMovementModeFromSettings()
    local cameraMode = Players.LocalPlayer.CameraMode

    if cameraMode == Enum.CameraMode.LockFirstPerson then
        return CameraUtils.ConvertCameraModeEnumToStandard(Enum.ComputerCameraMovementMode.Classic)
    end

    local devMode, userMode

    if UserInputService.TouchEnabled then
        devMode = CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevTouchCameraMode)
        userMode = CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
    else
        devMode = CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevComputerCameraMode)
        userMode = CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)
    end
    if devMode == Enum.DevComputerCameraMovementMode.UserChoice then
        return userMode
    end

    return devMode
end
function CameraModule:ActivateOcclusionModule(occlusionMode)
    local newModuleCreator

    if occlusionMode == Enum.DevCameraOcclusionMode.Zoom then
        newModuleCreator = Poppercam
    elseif occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then
        newModuleCreator = Invisicam
    else
        warn(
[[CameraScript ActivateOcclusionModule called with unsupported mode]])

        return
    end

    self.occlusionMode = occlusionMode

    if self.activeOcclusionModule and self.activeOcclusionModule:GetOcclusionMode() == occlusionMode then
        if not self.activeOcclusionModule:GetEnabled() then
            self.activeOcclusionModule:Enable(true)
        end

        return
    end

    local prevOcclusionModule = self.activeOcclusionModule

    self.activeOcclusionModule = instantiatedOcclusionModules[newModuleCreator]

    if not self.activeOcclusionModule then
        self.activeOcclusionModule = newModuleCreator.new()

        if self.activeOcclusionModule then
            instantiatedOcclusionModules[newModuleCreator] = self.activeOcclusionModule
        end
    end
    if self.activeOcclusionModule then
        local newModuleOcclusionMode = self.activeOcclusionModule:GetOcclusionMode()

        if newModuleOcclusionMode ~= occlusionMode then
            warn('CameraScript ActivateOcclusionModule mismatch: ', self.activeOcclusionModule:GetOcclusionMode(), '~=', occlusionMode)
        end
        if prevOcclusionModule then
            if prevOcclusionModule ~= self.activeOcclusionModule then
                prevOcclusionModule:Enable(false)
            else
                warn(
[[CameraScript ActivateOcclusionModule failure to detect already running correct module]])
            end
        end
        if occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then
            if Players.LocalPlayer.Character then
                self.activeOcclusionModule:CharacterAdded(Players.LocalPlayer.Character, Players.LocalPlayer)
            end
        else
            for _, player in pairs(Players:GetPlayers())do
                if player and player.Character then
                    self.activeOcclusionModule:CharacterAdded(player.Character, player)
                end
            end

            self.activeOcclusionModule:OnCameraSubjectChanged(game.Workspace.CurrentCamera.CameraSubject)
        end

        self.activeOcclusionModule:Enable(true)
    end
end
function CameraModule:ShouldUseVehicleCamera()
    local camera = workspace.CurrentCamera

    if not camera then
        return false
    end

    local cameraType = camera.CameraType
    local cameraSubject = camera.CameraSubject
    local isEligibleType = cameraType == Enum.CameraType.Custom or cameraType == Enum.CameraType.Follow
    local isEligibleSubject = cameraSubject and cameraSubject:IsA('VehicleSeat') or false
    local isEligibleOcclusionMode = self.occlusionMode ~= Enum.DevCameraOcclusionMode.Invisicam

    return isEligibleSubject and isEligibleType and isEligibleOcclusionMode
end
function CameraModule:ActivateCameraController(
    cameraMovementMode,
    legacyCameraType
)
    local newCameraCreator = nil

    if legacyCameraType ~= nil then
        if legacyCameraType == Enum.CameraType.Scriptable then
            if FFlagUserFixCameraSelectModuleWarning then
                if self.activeCameraController then
                    self.activeCameraController:Enable(false)

                    self.activeCameraController = nil
                end

                return
            else
                if self.activeCameraController then
                    self.activeCameraController:Enable(false)

                    self.activeCameraController = nil

                    return
                end
            end
        elseif legacyCameraType == Enum.CameraType.Custom then
            cameraMovementMode = self:GetCameraMovementModeFromSettings()
        elseif legacyCameraType == Enum.CameraType.Track then
            cameraMovementMode = Enum.ComputerCameraMovementMode.Classic
        elseif legacyCameraType == Enum.CameraType.Follow then
            cameraMovementMode = Enum.ComputerCameraMovementMode.Follow
        elseif legacyCameraType == Enum.CameraType.Orbital then
            cameraMovementMode = Enum.ComputerCameraMovementMode.Orbital
        elseif legacyCameraType == Enum.CameraType.Attach or legacyCameraType == Enum.CameraType.Watch or legacyCameraType == Enum.CameraType.Fixed then
            newCameraCreator = LegacyCamera
        else
            warn(
[[CameraScript encountered an unhandled Camera.CameraType value: ]], legacyCameraType)
        end
    end
    if not newCameraCreator then
        if FFlagUserFlagEnableNewVRSystem and VRService.VREnabled then
            newCameraCreator = VRCamera
        elseif cameraMovementMode == Enum.ComputerCameraMovementMode.Classic or cameraMovementMode == Enum.ComputerCameraMovementMode.Follow or cameraMovementMode == Enum.ComputerCameraMovementMode.Default or cameraMovementMode == Enum.ComputerCameraMovementMode.CameraToggle then
            newCameraCreator = ClassicCamera
        elseif cameraMovementMode == Enum.ComputerCameraMovementMode.Orbital then
            newCameraCreator = OrbitalCamera
        else
            warn('ActivateCameraController did not select a module.')

            return
        end
    end

    local isVehicleCamera = self:ShouldUseVehicleCamera()

    if isVehicleCamera then
        if FFlagUserFlagEnableNewVRSystem and VRService.VREnabled then
            newCameraCreator = VRVehicleCamera
        else
            newCameraCreator = VehicleCamera
        end
    end

    local newCameraController

    if not instantiatedCameraControllers[newCameraCreator] then
        newCameraController = newCameraCreator.new()
        instantiatedCameraControllers[newCameraCreator] = newCameraController
    else
        newCameraController = instantiatedCameraControllers[newCameraCreator]

        if newCameraController.Reset then
            newCameraController:Reset()
        end
    end
    if self.activeCameraController then
        if self.activeCameraController ~= newCameraController then
            self.activeCameraController:Enable(false)

            self.activeCameraController = newCameraController

            self.activeCameraController:Enable(true)
        elseif not self.activeCameraController:GetEnabled() then
            self.activeCameraController:Enable(true)
        end
    elseif newCameraController ~= nil then
        self.activeCameraController = newCameraController

        self.activeCameraController:Enable(true)
    end
    if self.activeCameraController then
        if cameraMovementMode ~= nil then
            self.activeCameraController:SetCameraMovementMode(cameraMovementMode)
        elseif legacyCameraType ~= nil then
            self.activeCameraController:SetCameraType(legacyCameraType)
        end
    end
end
function CameraModule:OnCameraSubjectChanged()
    local camera = workspace.CurrentCamera
    local cameraSubject = camera and camera.CameraSubject

    if self.activeTransparencyController then
        self.activeTransparencyController:SetSubject(cameraSubject)
    end
    if self.activeOcclusionModule then
        self.activeOcclusionModule:OnCameraSubjectChanged(cameraSubject)
    end

    self:ActivateCameraController(nil, camera.CameraType)
end
function CameraModule:OnCameraTypeChanged(newCameraType)
    if newCameraType == Enum.CameraType.Scriptable then
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            if FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame then
                CameraUtils.restoreMouseBehavior()
            else
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end
    end

    self:ActivateCameraController(nil, newCameraType)
end
function CameraModule:OnCurrentCameraChanged()
    local currentCamera = game.Workspace.CurrentCamera

    if not currentCamera then
        return
    end
    if self.cameraSubjectChangedConn then
        self.cameraSubjectChangedConn:Disconnect()
    end
    if self.cameraTypeChangedConn then
        self.cameraTypeChangedConn:Disconnect()
    end

    self.cameraSubjectChangedConn = currentCamera:GetPropertyChangedSignal('CameraSubject'):Connect(function(
    )
        self:OnCameraSubjectChanged(currentCamera.CameraSubject)
    end)
    self.cameraTypeChangedConn = currentCamera:GetPropertyChangedSignal('CameraType'):Connect(function(
    )
        self:OnCameraTypeChanged(currentCamera.CameraType)
    end)

    self:OnCameraSubjectChanged(currentCamera.CameraSubject)
    self:OnCameraTypeChanged(currentCamera.CameraType)
end
function CameraModule:OnLocalPlayerCameraPropertyChanged(propertyName)
    if propertyName == 'CameraMode' then
        if Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
            if not self.activeCameraController or self.activeCameraController:GetModuleName() ~= 'ClassicCamera' then
                self:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard(Enum.DevComputerCameraMovementMode.Classic))
            end
            if self.activeCameraController then
                self.activeCameraController:UpdateForDistancePropertyChange()
            end
        elseif Players.LocalPlayer.CameraMode == Enum.CameraMode.Classic then
            local cameraMovementMode = self:GetCameraMovementModeFromSettings()

            self:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard(cameraMovementMode))
        else
            warn('Unhandled value for property player.CameraMode: ', Players.LocalPlayer.CameraMode)
        end
    elseif propertyName == 'DevComputerCameraMode' or propertyName == 'DevTouchCameraMode' then
        local cameraMovementMode = self:GetCameraMovementModeFromSettings()

        self:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard(cameraMovementMode))
    elseif propertyName == 'DevCameraOcclusionMode' then
        self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
    elseif propertyName == 'CameraMinZoomDistance' or propertyName == 'CameraMaxZoomDistance' then
        if self.activeCameraController then
            self.activeCameraController:UpdateForDistancePropertyChange()
        end
    elseif propertyName == 'DevTouchMovementMode' then
    elseif propertyName == 'DevComputerMovementMode' then
    elseif propertyName == 'DevEnableMouseLock' then
    end
end
function CameraModule:OnUserGameSettingsPropertyChanged(propertyName)
    if propertyName == 'ComputerCameraMovementMode' then
        local cameraMovementMode = self:GetCameraMovementModeFromSettings()

        self:ActivateCameraController(CameraUtils.ConvertCameraModeEnumToStandard(cameraMovementMode))
    end
end
function CameraModule:Update(dt)
    if self.activeCameraController then
        self.activeCameraController:UpdateMouseBehavior()

        local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)

        if not FFlagUserFlagEnableNewVRSystem then
            self.activeCameraController:ApplyVRTransform()
        end
        if self.activeOcclusionModule then
            newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)
        end

        game.Workspace.CurrentCamera.CFrame = newCameraCFrame
        game.Workspace.CurrentCamera.Focus = newCameraFocus

        if self.activeTransparencyController then
            self.activeTransparencyController:Update()
        end
        if CameraInput.getInputEnabled() then
            CameraInput.resetInputForFrameEnd()
        end
    end
end
function CameraModule:GetCameraControlChoice()
    local player = Players.LocalPlayer

    if player then
        if self.lastInputType == Enum.UserInputType.Touch or UserInputService.TouchEnabled then
            if player.DevTouchCameraMode == Enum.DevTouchCameraMovementMode.UserChoice then
                return CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
            else
                return CameraUtils.ConvertCameraModeEnumToStandard(player.DevTouchCameraMode)
            end
        else
            if player.DevComputerCameraMode == Enum.DevComputerCameraMovementMode.UserChoice then
                local computerMovementMode = CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)

                return CameraUtils.ConvertCameraModeEnumToStandard(computerMovementMode)
            else
                return CameraUtils.ConvertCameraModeEnumToStandard(player.DevComputerCameraMode)
            end
        end
    end
end
function CameraModule:OnCharacterAdded(char, player)
    if self.activeOcclusionModule then
        self.activeOcclusionModule:CharacterAdded(char, player)
    end
end
function CameraModule:OnCharacterRemoving(char, player)
    if self.activeOcclusionModule then
        self.activeOcclusionModule:CharacterRemoving(char, player)
    end
end
function CameraModule:OnPlayerAdded(player)
    player.CharacterAdded:Connect(function(char)
        self:OnCharacterAdded(char, player)
    end)
    player.CharacterRemoving:Connect(function(char)
        self:OnCharacterRemoving(char, player)
    end)
end
function CameraModule:OnMouseLockToggled()
    if self.activeMouseLockController then
        local mouseLocked = self.activeMouseLockController:GetIsMouseLocked()
        local mouseLockOffset = self.activeMouseLockController:GetMouseLockOffset()

        if self.activeCameraController then
            self.activeCameraController:SetIsMouseLocked(mouseLocked)
            self.activeCameraController:SetMouseLockOffset(mouseLockOffset)
        end
    end
end

local cameraModuleObject = CameraModule.new()
local cameraApi = {}

if FFlagUserRemoveTheCameraApi then
    return cameraApi
else
    return cameraModuleObject
end
