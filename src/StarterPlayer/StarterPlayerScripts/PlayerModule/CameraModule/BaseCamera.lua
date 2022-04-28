-- # selene: allow(unused_variable)

local UNIT_Z = Vector3.new(0, 0, 1)
local X1_Y0_Z1 = Vector3.new(1, 0, 1)
local DEFAULT_DISTANCE = 12.5
local PORTRAIT_DEFAULT_DISTANCE = 25
local FIRST_PERSON_DISTANCE_THRESHOLD = 1
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)
local VR_ANGLE = math.rad(15)
local VR_LOW_INTENSITY_ROTATION = Vector2.new(math.rad(15), 0)
local VR_HIGH_INTENSITY_ROTATION = Vector2.new(math.rad(45), 0)
local VR_LOW_INTENSITY_REPEAT = 0.1
local VR_HIGH_INTENSITY_REPEAT = 0.4
local ZERO_VECTOR2 = Vector2.new(0, 0)
local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local SEAT_OFFSET = Vector3.new(0, 5, 0)
local VR_SEAT_OFFSET = Vector3.new(0, 4, 0)
local HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET_NO_SCALING = Vector3.new(0, 2, 0)
local HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)
local GAMEPAD_ZOOM_STEP_1 = 0
local GAMEPAD_ZOOM_STEP_2 = 10
local GAMEPAD_ZOOM_STEP_3 = 20
local ZOOM_SENSITIVITY_CURVATURE = 0.5
local FIRST_PERSON_DISTANCE_MIN = 0.5
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
local ZoomController = require(script.Parent:WaitForChild("ZoomController"))
local CameraToggleStateController = require(script.Parent:WaitForChild("CameraToggleStateController"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local CameraUI = require(script.Parent:WaitForChild("CameraUI"))
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local VRService = game:GetService("VRService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local player = Players.LocalPlayer
local FFlagUserFlagEnableNewVRSystem

do
	local success, result = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserFlagEnableNewVRSystem")
	end)

	FFlagUserFlagEnableNewVRSystem = success and result
end

local FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame

do
	local success, value = pcall(function()
		return UserSettings():IsUserFeatureEnabled([[UserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame]])
	end)

	FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame = success and value
end

local BaseCamera = {}

BaseCamera.__index = BaseCamera

function BaseCamera.new()
	local self = setmetatable({}, BaseCamera)

	self.FIRST_PERSON_DISTANCE_THRESHOLD = FIRST_PERSON_DISTANCE_THRESHOLD
	self.cameraType = nil
	self.cameraMovementMode = nil
	self.lastCameraTransform = nil
	self.lastUserPanCamera = tick()
	self.humanoidRootPart = nil
	self.humanoidCache = {}
	self.lastSubject = nil
	self.lastSubjectPosition = Vector3.new(0, 5, 0)
	self.lastSubjectCFrame = CFrame.new(self.lastSubjectPosition)
	self.defaultSubjectDistance = math.clamp(
		DEFAULT_DISTANCE,
		player.CameraMinZoomDistance,
		player.CameraMaxZoomDistance
	)
	self.currentSubjectDistance = math.clamp(
		DEFAULT_DISTANCE,
		player.CameraMinZoomDistance,
		player.CameraMaxZoomDistance
	)
	self.inFirstPerson = false
	self.inMouseLockedMode = false
	self.portraitMode = false
	self.isSmallTouchScreen = false
	self.resetCameraAngle = true
	self.enabled = false
	self.PlayerGui = nil
	self.cameraChangedConn = nil
	self.viewportSizeChangedConn = nil
	self.shouldUseVRRotation = false
	self.VRRotationIntensityAvailable = false
	self.lastVRRotationIntensityCheckTime = 0
	self.lastVRRotationTime = 0
	self.vrRotateKeyCooldown = {}
	self.cameraTranslationConstraints = Vector3.new(1, 1, 1)
	self.humanoidJumpOrigin = nil
	self.trackingHumanoid = nil
	self.cameraFrozen = false
	self.subjectStateChangedConn = nil
	self.gamepadZoomPressConnection = nil
	self.mouseLockOffset = ZERO_VECTOR3

	if player.Character then
		self:OnCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char)
	end)

	if self.cameraChangedConn then
		self.cameraChangedConn:Disconnect()
	end

	self.cameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:OnCurrentCameraChanged()
	end)

	self:OnCurrentCameraChanged()

	if self.playerCameraModeChangeConn then
		self.playerCameraModeChangeConn:Disconnect()
	end

	self.playerCameraModeChangeConn = player:GetPropertyChangedSignal("CameraMode"):Connect(function()
		self:OnPlayerCameraPropertyChange()
	end)

	if self.minDistanceChangeConn then
		self.minDistanceChangeConn:Disconnect()
	end

	self.minDistanceChangeConn = player:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function()
		self:OnPlayerCameraPropertyChange()
	end)

	if self.maxDistanceChangeConn then
		self.maxDistanceChangeConn:Disconnect()
	end

	self.maxDistanceChangeConn = player:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
		self:OnPlayerCameraPropertyChange()
	end)

	if self.playerDevTouchMoveModeChangeConn then
		self.playerDevTouchMoveModeChangeConn:Disconnect()
	end

	self.playerDevTouchMoveModeChangeConn = player:GetPropertyChangedSignal("DevTouchMovementMode"):Connect(function()
		self:OnDevTouchMovementModeChanged()
	end)

	self:OnDevTouchMovementModeChanged()

	if self.gameSettingsTouchMoveMoveChangeConn then
		self.gameSettingsTouchMoveMoveChangeConn:Disconnect()
	end

	self.gameSettingsTouchMoveMoveChangeConn = UserGameSettings
		:GetPropertyChangedSignal("TouchMovementMode")
		:Connect(function()
			self:OnGameSettingsTouchMovementModeChanged()
		end)

	self:OnGameSettingsTouchMovementModeChanged()
	UserGameSettings:SetCameraYInvertVisible()
	UserGameSettings:SetGamepadCameraSensitivityVisible()

	self.hasGameLoaded = game:IsLoaded()

	if not self.hasGameLoaded then
		self.gameLoadedConn = game.Loaded:Connect(function()
			self.hasGameLoaded = true

			self.gameLoadedConn:Disconnect()

			self.gameLoadedConn = nil
		end)
	end

	self:OnPlayerCameraPropertyChange()

	return self
end
function BaseCamera:GetModuleName()
	return "BaseCamera"
end
function BaseCamera:OnCharacterAdded(char)
	self.resetCameraAngle = self.resetCameraAngle or self:GetEnabled()
	self.humanoidRootPart = nil

	if UserInputService.TouchEnabled then
		self.PlayerGui = player:WaitForChild("PlayerGui")

		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				self.isAToolEquipped = true
			end
		end

		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				self.isAToolEquipped = true
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				self.isAToolEquipped = false
			end
		end)
	end
end
function BaseCamera:GetHumanoidRootPart()
	if not self.humanoidRootPart then
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				self.humanoidRootPart = humanoid.RootPart
			end
		end
	end

	return self.humanoidRootPart
end
function BaseCamera:GetBodyPartToFollow(humanoid, isDead)
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		local character = humanoid.Parent

		if character and character:IsA("Model") then
			return character:FindFirstChild("Head") or humanoid.RootPart
		end
	end

	return humanoid.RootPart
end
function BaseCamera:GetSubjectCFrame()
	local result = self.lastSubjectCFrame
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if not cameraSubject then
		return result
	end
	if cameraSubject:IsA("Humanoid") then
		local humanoid = cameraSubject
		local humanoidIsDead = humanoid:GetState() == Enum.HumanoidStateType.Dead

		if
			(VRService.VREnabled and not FFlagUserFlagEnableNewVRSystem)
			and humanoidIsDead
			and humanoid == self.lastSubject
		then
			result = self.lastSubjectCFrame
		else
			local bodyPartToFollow = humanoid.RootPart

			if humanoidIsDead then
				if humanoid.Parent and humanoid.Parent:IsA("Model") then
					bodyPartToFollow = humanoid.Parent:FindFirstChild("Head") or bodyPartToFollow
				end
			end
			if bodyPartToFollow and bodyPartToFollow:IsA("BasePart") then
				local heightOffset

				if humanoid.RigType == Enum.HumanoidRigType.R15 then
					if humanoid.AutomaticScalingEnabled then
						heightOffset = R15_HEAD_OFFSET

						local rootPart = humanoid.RootPart

						if bodyPartToFollow == rootPart then
							local rootPartSizeOffset = (rootPart.Size.Y - HUMANOID_ROOT_PART_SIZE.Y) / 2

							heightOffset = heightOffset + Vector3.new(0, rootPartSizeOffset, 0)
						end
					else
						heightOffset = R15_HEAD_OFFSET_NO_SCALING
					end
				else
					heightOffset = HEAD_OFFSET
				end
				if humanoidIsDead then
					heightOffset = ZERO_VECTOR3
				end

				result = bodyPartToFollow.CFrame * CFrame.new(heightOffset + humanoid.CameraOffset)
			end
		end
	elseif cameraSubject:IsA("BasePart") then
		result = cameraSubject.CFrame
	elseif cameraSubject:IsA("Model") then
		if cameraSubject.PrimaryPart then
			result = cameraSubject:GetPrimaryPartCFrame()
		else
			result = CFrame.new()
		end
	end
	if result then
		self.lastSubjectCFrame = result
	end

	return result
end
function BaseCamera:GetSubjectVelocity()
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if not cameraSubject then
		return ZERO_VECTOR3
	end
	if cameraSubject:IsA("BasePart") then
		return cameraSubject.Velocity
	elseif cameraSubject:IsA("Humanoid") then
		local rootPart = cameraSubject.RootPart

		if rootPart then
			return rootPart.Velocity
		end
	elseif cameraSubject:IsA("Model") then
		local primaryPart = cameraSubject.PrimaryPart

		if primaryPart then
			return primaryPart.Velocity
		end
	end

	return ZERO_VECTOR3
end
function BaseCamera:GetSubjectRotVelocity()
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if not cameraSubject then
		return ZERO_VECTOR3
	end
	if cameraSubject:IsA("BasePart") then
		return cameraSubject.RotVelocity
	elseif cameraSubject:IsA("Humanoid") then
		local rootPart = cameraSubject.RootPart

		if rootPart then
			return rootPart.RotVelocity
		end
	elseif cameraSubject:IsA("Model") then
		local primaryPart = cameraSubject.PrimaryPart

		if primaryPart then
			return primaryPart.RotVelocity
		end
	end

	return ZERO_VECTOR3
end
function BaseCamera:StepZoom()
	local zoom = self.currentSubjectDistance
	local zoomDelta = CameraInput.getZoomDelta()

	if math.abs(zoomDelta) > 0 then
		local newZoom

		if zoomDelta > 0 then
			newZoom = zoom + zoomDelta * (1 + zoom * ZOOM_SENSITIVITY_CURVATURE)
			newZoom = math.max(newZoom, self.FIRST_PERSON_DISTANCE_THRESHOLD)
		else
			newZoom = (zoom + zoomDelta) / (1 - zoomDelta * ZOOM_SENSITIVITY_CURVATURE)
			newZoom = math.max(newZoom, FIRST_PERSON_DISTANCE_MIN)
		end
		if newZoom < self.FIRST_PERSON_DISTANCE_THRESHOLD then
			newZoom = FIRST_PERSON_DISTANCE_MIN
		end

		self:SetCameraToSubjectDistance(newZoom)
	end

	return ZoomController.GetZoomRadius()
end
function BaseCamera:GetSubjectPosition()
	local result = self.lastSubjectPosition
	local camera = game.Workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if cameraSubject then
		if cameraSubject:IsA("Humanoid") then
			local humanoid = cameraSubject
			local humanoidIsDead = humanoid:GetState() == Enum.HumanoidStateType.Dead

			if
				(VRService.VREnabled and not FFlagUserFlagEnableNewVRSystem)
				and humanoidIsDead
				and humanoid == self.lastSubject
			then
				result = self.lastSubjectPosition
			else
				local bodyPartToFollow = humanoid.RootPart

				if humanoidIsDead then
					if humanoid.Parent and humanoid.Parent:IsA("Model") then
						bodyPartToFollow = humanoid.Parent:FindFirstChild("Head") or bodyPartToFollow
					end
				end
				if bodyPartToFollow and bodyPartToFollow:IsA("BasePart") then
					local heightOffset

					if humanoid.RigType == Enum.HumanoidRigType.R15 then
						if humanoid.AutomaticScalingEnabled then
							heightOffset = R15_HEAD_OFFSET

							if bodyPartToFollow == humanoid.RootPart then
								local rootPartSizeOffset = (humanoid.RootPart.Size.Y / 2)
									- (HUMANOID_ROOT_PART_SIZE.Y / 2)

								heightOffset = heightOffset + Vector3.new(0, rootPartSizeOffset, 0)
							end
						else
							heightOffset = R15_HEAD_OFFSET_NO_SCALING
						end
					else
						heightOffset = HEAD_OFFSET
					end
					if humanoidIsDead then
						heightOffset = ZERO_VECTOR3
					end

					result = bodyPartToFollow.CFrame.p
						+ bodyPartToFollow.CFrame:vectorToWorldSpace(heightOffset + humanoid.CameraOffset)
				end
			end
		elseif cameraSubject:IsA("VehicleSeat") then
			local offset = SEAT_OFFSET

			if VRService.VREnabled and not FFlagUserFlagEnableNewVRSystem then
				offset = VR_SEAT_OFFSET
			end

			result = cameraSubject.CFrame.p + cameraSubject.CFrame:vectorToWorldSpace(offset)
		elseif cameraSubject:IsA("SkateboardPlatform") then
			result = cameraSubject.CFrame.p + SEAT_OFFSET
		elseif cameraSubject:IsA("BasePart") then
			result = cameraSubject.CFrame.p
		elseif cameraSubject:IsA("Model") then
			if cameraSubject.PrimaryPart then
				result = cameraSubject:GetPrimaryPartCFrame().p
			else
				result = cameraSubject:GetModelCFrame().p
			end
		end
	else
		return
	end

	self.lastSubject = cameraSubject
	self.lastSubjectPosition = result

	return result
end
function BaseCamera:UpdateDefaultSubjectDistance()
	if self.portraitMode then
		self.defaultSubjectDistance = math.clamp(
			PORTRAIT_DEFAULT_DISTANCE,
			player.CameraMinZoomDistance,
			player.CameraMaxZoomDistance
		)
	else
		self.defaultSubjectDistance = math.clamp(
			DEFAULT_DISTANCE,
			player.CameraMinZoomDistance,
			player.CameraMaxZoomDistance
		)
	end
end
function BaseCamera:OnViewportSizeChanged()
	local camera = game.Workspace.CurrentCamera
	local size = camera.ViewportSize

	self.portraitMode = size.X < size.Y
	self.isSmallTouchScreen = UserInputService.TouchEnabled and (size.Y < 500 or size.X < 700)

	self:UpdateDefaultSubjectDistance()
end
function BaseCamera:OnCurrentCameraChanged()
	if UserInputService.TouchEnabled then
		if self.viewportSizeChangedConn then
			self.viewportSizeChangedConn:Disconnect()

			self.viewportSizeChangedConn = nil
		end

		local newCamera = game.Workspace.CurrentCamera

		if newCamera then
			self:OnViewportSizeChanged()

			self.viewportSizeChangedConn = newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:OnViewportSizeChanged()
			end)
		end
	end
	if self.cameraSubjectChangedConn then
		self.cameraSubjectChangedConn:Disconnect()

		self.cameraSubjectChangedConn = nil
	end

	local camera = game.Workspace.CurrentCamera

	if camera then
		self.cameraSubjectChangedConn = camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
			self:OnNewCameraSubject()
		end)

		self:OnNewCameraSubject()
	end
end
function BaseCamera:OnDynamicThumbstickEnabled()
	if UserInputService.TouchEnabled then
		self.isDynamicThumbstickEnabled = true
	end
end
function BaseCamera:OnDynamicThumbstickDisabled()
	self.isDynamicThumbstickEnabled = false
end
function BaseCamera:OnGameSettingsTouchMovementModeChanged()
	if player.DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice then
		if
			UserGameSettings.TouchMovementMode == Enum.TouchMovementMode.DynamicThumbstick
			or UserGameSettings.TouchMovementMode == Enum.TouchMovementMode.Default
		then
			self:OnDynamicThumbstickEnabled()
		else
			self:OnDynamicThumbstickDisabled()
		end
	end
end
function BaseCamera:OnDevTouchMovementModeChanged()
	if player.DevTouchMovementMode == Enum.DevTouchMovementMode.DynamicThumbstick then
		self:OnDynamicThumbstickEnabled()
	else
		self:OnGameSettingsTouchMovementModeChanged()
	end
end
function BaseCamera:OnPlayerCameraPropertyChange()
	self:SetCameraToSubjectDistance(self.currentSubjectDistance)
end
function BaseCamera:InputTranslationToCameraAngleChange(translationVector, sensitivity)
	return translationVector * sensitivity
end
function BaseCamera:GamepadZoomPress()
	local dist = self:GetCameraToSubjectDistance()

	if dist > (GAMEPAD_ZOOM_STEP_2 + GAMEPAD_ZOOM_STEP_3) / 2 then
		self:SetCameraToSubjectDistance(GAMEPAD_ZOOM_STEP_2)
	elseif dist > (GAMEPAD_ZOOM_STEP_1 + GAMEPAD_ZOOM_STEP_2) / 2 then
		self:SetCameraToSubjectDistance(GAMEPAD_ZOOM_STEP_1)
	else
		self:SetCameraToSubjectDistance(GAMEPAD_ZOOM_STEP_3)
	end
end
function BaseCamera:Enable(enable)
	if self.enabled ~= enable then
		self.enabled = enable

		if self.enabled then
			CameraInput.setInputEnabled(true)

			self.gamepadZoomPressConnection = CameraInput.gamepadZoomPress:Connect(function()
				self:GamepadZoomPress()
			end)

			if player.CameraMode == Enum.CameraMode.LockFirstPerson then
				self.currentSubjectDistance = 0.5

				if not self.inFirstPerson then
					self:EnterFirstPerson()
				end
			end
		else
			CameraInput.setInputEnabled(false)

			if self.gamepadZoomPressConnection then
				self.gamepadZoomPressConnection:Disconnect()

				self.gamepadZoomPressConnection = nil
			end

			self:Cleanup()
		end

		self:OnEnable(enable)
	end
end
function BaseCamera:OnEnable(enable) end
function BaseCamera:GetEnabled()
	return self.enabled
end
function BaseCamera:Cleanup()
	if self.subjectStateChangedConn then
		self.subjectStateChangedConn:Disconnect()

		self.subjectStateChangedConn = nil
	end
	if self.viewportSizeChangedConn then
		self.viewportSizeChangedConn:Disconnect()

		self.viewportSizeChangedConn = nil
	end

	self.lastCameraTransform = nil
	self.lastSubjectCFrame = nil

	if FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame then
		CameraUtils.restoreMouseBehavior()
	else
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
end
function BaseCamera:UpdateMouseBehavior()
	local blockToggleDueToClickToMove = UserGameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove

	if self.isCameraToggle and blockToggleDueToClickToMove == false then
		CameraUI.setCameraModeToastEnabled(true)
		CameraInput.enableCameraToggleInput()
		CameraToggleStateController(self.inFirstPerson)
	else
		CameraUI.setCameraModeToastEnabled(false)
		CameraInput.disableCameraToggleInput()

		if self.inFirstPerson or self.inMouseLockedMode then
			if FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame then
				CameraUtils.setRotationTypeOverride(Enum.RotationType.CameraRelative)
				CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
			else
				UserGameSettings.RotationType = Enum.RotationType.CameraRelative
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
		else
			if FFlagUserCameraToggleDontSetMouseBehaviorOrRotationTypeEveryFrame then
				CameraUtils.restoreRotationType()
				CameraUtils.restoreMouseBehavior()
			else
				UserGameSettings.RotationType = Enum.RotationType.MovementRelative
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end
end
function BaseCamera:UpdateForDistancePropertyChange()
	self:SetCameraToSubjectDistance(self.currentSubjectDistance)
end
function BaseCamera:SetCameraToSubjectDistance(desiredSubjectDistance)
	local lastSubjectDistance = self.currentSubjectDistance

	if player.CameraMode == Enum.CameraMode.LockFirstPerson then
		self.currentSubjectDistance = 0.5

		if not self.inFirstPerson then
			self:EnterFirstPerson()
		end
	else
		local newSubjectDistance = math.clamp(
			desiredSubjectDistance,
			player.CameraMinZoomDistance,
			player.CameraMaxZoomDistance
		)

		if newSubjectDistance < FIRST_PERSON_DISTANCE_THRESHOLD then
			self.currentSubjectDistance = 0.5

			if not self.inFirstPerson then
				self:EnterFirstPerson()
			end
		else
			self.currentSubjectDistance = newSubjectDistance

			if self.inFirstPerson then
				self:LeaveFirstPerson()
			end
		end
	end

	ZoomController.SetZoomParameters(
		self.currentSubjectDistance,
		math.sign(desiredSubjectDistance - lastSubjectDistance)
	)

	return self.currentSubjectDistance
end
function BaseCamera:SetCameraType(cameraType)
	self.cameraType = cameraType
end
function BaseCamera:GetCameraType()
	return self.cameraType
end
function BaseCamera:SetCameraMovementMode(cameraMovementMode)
	self.cameraMovementMode = cameraMovementMode
end
function BaseCamera:GetCameraMovementMode()
	return self.cameraMovementMode
end
function BaseCamera:SetIsMouseLocked(mouseLocked)
	self.inMouseLockedMode = mouseLocked
end
function BaseCamera:GetIsMouseLocked()
	return self.inMouseLockedMode
end
function BaseCamera:SetMouseLockOffset(offsetVector)
	self.mouseLockOffset = offsetVector
end
function BaseCamera:GetMouseLockOffset()
	return self.mouseLockOffset
end
function BaseCamera:InFirstPerson()
	return self.inFirstPerson
end
function BaseCamera:EnterFirstPerson() end
function BaseCamera:LeaveFirstPerson() end
function BaseCamera:GetCameraToSubjectDistance()
	return self.currentSubjectDistance
end
function BaseCamera:GetMeasuredDistanceToFocus()
	local camera = game.Workspace.CurrentCamera

	if camera then
		return (camera.CoordinateFrame.p - camera.Focus.p).magnitude
	end

	return nil
end
function BaseCamera:GetCameraLookVector()
	return game.Workspace.CurrentCamera and game.Workspace.CurrentCamera.CFrame.lookVector or UNIT_Z
end
function BaseCamera:CalculateNewLookCFrameFromArg(suppliedLookVector, rotateInput)
	local currLookVector = suppliedLookVector or self:GetCameraLookVector()
	local currPitchAngle = math.asin(currLookVector.y)
	local yTheta = math.clamp(rotateInput.y, -MAX_Y + currPitchAngle, -MIN_Y + currPitchAngle)
	local constrainedRotateInput = Vector2.new(rotateInput.x, yTheta)
	local startCFrame = CFrame.new(ZERO_VECTOR3, currLookVector)
	local newLookCFrame = CFrame.Angles(0, -constrainedRotateInput.x, 0)
		* startCFrame
		* CFrame.Angles(-constrainedRotateInput.y, 0, 0)

	return newLookCFrame
end
function BaseCamera:CalculateNewLookVectorFromArg(suppliedLookVector, rotateInput)
	local newLookCFrame = self:CalculateNewLookCFrameFromArg(suppliedLookVector, rotateInput)

	return newLookCFrame.lookVector
end
function BaseCamera:CalculateNewLookVectorVRFromArg(rotateInput)
	local subjectPosition = self:GetSubjectPosition()
	local vecToSubject = (subjectPosition - game.Workspace.CurrentCamera.CFrame.p)
	local currLookVector = (vecToSubject * X1_Y0_Z1).unit
	local vrRotateInput = Vector2.new(rotateInput.x, 0)
	local startCFrame = CFrame.new(ZERO_VECTOR3, currLookVector)
	local yawRotatedVector = (CFrame.Angles(0, -vrRotateInput.x, 0) * startCFrame * CFrame.Angles(
		-vrRotateInput.y,
		0,
		0
	)).lookVector

	return (yawRotatedVector * X1_Y0_Z1).unit
end
function BaseCamera:GetHumanoid()
	local character = player and player.Character

	if character then
		local resultHumanoid = self.humanoidCache[player]

		if resultHumanoid and resultHumanoid.Parent == character then
			return resultHumanoid
		else
			self.humanoidCache[player] = nil

			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				self.humanoidCache[player] = humanoid
			end

			return humanoid
		end
	end

	return nil
end
function BaseCamera:GetHumanoidPartToFollow(humanoid, humanoidStateType)
	if humanoidStateType == Enum.HumanoidStateType.Dead then
		local character = humanoid.Parent

		if character then
			return character:FindFirstChild("Head") or humanoid.Torso
		else
			return humanoid.Torso
		end
	else
		return humanoid.Torso
	end
end
function BaseCamera:OnNewCameraSubject()
	if self.subjectStateChangedConn then
		self.subjectStateChangedConn:Disconnect()

		self.subjectStateChangedConn = nil
	end
	if not FFlagUserFlagEnableNewVRSystem then
		local humanoid = workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject

		if self.trackingHumanoid ~= humanoid then
			self:CancelCameraFreeze()
		end
		if humanoid and humanoid:IsA("Humanoid") then
			self.subjectStateChangedConn = humanoid.StateChanged:Connect(function(oldState, newState)
				if VRService.VREnabled and newState == Enum.HumanoidStateType.Jumping and not self.inFirstPerson then
					self:StartCameraFreeze(self:GetSubjectPosition(), humanoid)
				elseif newState ~= Enum.HumanoidStateType.Jumping and newState ~= Enum.HumanoidStateType.Freefall then
					self:CancelCameraFreeze(true)
				end
			end)
		end
	end
end
function BaseCamera:IsInFirstPerson()
	return self.inFirstPerson
end
function BaseCamera:Update(dt)
	error([[BaseCamera:Update() This is a virtual function that should never be getting called.]], 2)
end
function BaseCamera:GetCameraHeight()
	if VRService.VREnabled and not self.inFirstPerson then
		return math.sin(VR_ANGLE) * self.currentSubjectDistance
	end

	return 0
end

if not FFlagUserFlagEnableNewVRSystem then
	function BaseCamera:CancelCameraFreeze(keepConstraints)
		if not keepConstraints then
			self.cameraTranslationConstraints = Vector3.new(
				self.cameraTranslationConstraints.x,
				1,
				self.cameraTranslationConstraints.z
			)
		end
		if self.cameraFrozen then
			self.trackingHumanoid = nil
			self.cameraFrozen = false
		end
	end
	function BaseCamera:StartCameraFreeze(subjectPosition, humanoidToTrack)
		if not self.cameraFrozen then
			self.humanoidJumpOrigin = subjectPosition
			self.trackingHumanoid = humanoidToTrack
			self.cameraTranslationConstraints = Vector3.new(
				self.cameraTranslationConstraints.x,
				0,
				self.cameraTranslationConstraints.z
			)
			self.cameraFrozen = true
		end
	end
	function BaseCamera:ApplyVRTransform()
		if not VRService.VREnabled then
			return
		end

		local rootJoint = self.humanoidRootPart and self.humanoidRootPart:FindFirstChild("RootJoint")

		if not rootJoint then
			return
		end

		local cameraSubject = game.Workspace.CurrentCamera.CameraSubject
		local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")

		if self.inFirstPerson and not isInVehicle then
			local vrFrame = VRService:GetUserCFrame(Enum.UserCFrame.Head)
			local vrRotation = vrFrame - vrFrame.p

			rootJoint.C0 = CFrame.new(vrRotation:vectorToObjectSpace(vrFrame.p))
				* CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
		else
			rootJoint.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
		end
	end
	function BaseCamera:ShouldUseVRRotation()
		if not VRService.VREnabled then
			return false
		end
		if not self.VRRotationIntensityAvailable and tick() - self.lastVRRotationIntensityCheckTime < 1 then
			return false
		end

		local success, vrRotationIntensity = pcall(function()
			return StarterGui:GetCore("VRRotationIntensity")
		end)

		self.VRRotationIntensityAvailable = success and vrRotationIntensity ~= nil
		self.lastVRRotationIntensityCheckTime = tick()
		self.shouldUseVRRotation = success and vrRotationIntensity ~= nil and vrRotationIntensity ~= "Smooth"

		return self.shouldUseVRRotation
	end
	function BaseCamera:GetVRRotationInput()
		local vrRotateSum = ZERO_VECTOR2
		local success, vrRotationIntensity = pcall(function()
			return StarterGui:GetCore("VRRotationIntensity")
		end)

		if not success then
			return
		end

		local vrGamepadRotation = ZERO_VECTOR2
		local delayExpired = (tick() - self.lastVRRotationTime) >= self:GetRepeatDelayValue(vrRotationIntensity)

		if math.abs(vrGamepadRotation.x) >= self:GetActivateValue() then
			if delayExpired or not self.vrRotateKeyCooldown[Enum.KeyCode.Thumbstick2] then
				local sign = 1

				if vrGamepadRotation.x < 0 then
					sign = -1
				end

				vrRotateSum = vrRotateSum + self:GetRotateAmountValue(vrRotationIntensity) * sign
				self.vrRotateKeyCooldown[Enum.KeyCode.Thumbstick2] = true
			end
		elseif math.abs(vrGamepadRotation.x) < self:GetActivateValue() - 0.1 then
			self.vrRotateKeyCooldown[Enum.KeyCode.Thumbstick2] = nil
		end

		self.vrRotateKeyCooldown[Enum.KeyCode.Left] = nil
		self.vrRotateKeyCooldown[Enum.KeyCode.Right] = nil

		if vrRotateSum ~= ZERO_VECTOR2 then
			self.lastVRRotationTime = tick()
		end

		return vrRotateSum
	end
	function BaseCamera:GetVRFocus(subjectPosition, timeDelta)
		local lastFocus = self.LastCameraFocus or subjectPosition

		if not self.cameraFrozen then
			self.cameraTranslationConstraints = Vector3.new(
				self.cameraTranslationConstraints.x,
				math.min(1, self.cameraTranslationConstraints.y + 0.42 * timeDelta),
				self.cameraTranslationConstraints.z
			)
		end

		local newFocus

		if self.cameraFrozen and self.humanoidJumpOrigin and self.humanoidJumpOrigin.y > lastFocus.y then
			newFocus = CFrame.new(
				Vector3.new(
					subjectPosition.x,
					math.min(self.humanoidJumpOrigin.y, lastFocus.y + 5 * timeDelta),
					subjectPosition.z
				)
			)
		else
			newFocus = CFrame.new(
				Vector3.new(subjectPosition.x, lastFocus.y, subjectPosition.z):lerp(
					subjectPosition,
					self.cameraTranslationConstraints.y
				)
			)
		end
		if self.cameraFrozen then
			if self.inFirstPerson then
				self:CancelCameraFreeze()
			end
			if self.humanoidJumpOrigin and subjectPosition.y < (self.humanoidJumpOrigin.y - 0.5) then
				self:CancelCameraFreeze()
			end
		end

		return newFocus
	end
	function BaseCamera:GetRotateAmountValue(vrRotationIntensity)
		vrRotationIntensity = vrRotationIntensity or StarterGui:GetCore("VRRotationIntensity")

		if vrRotationIntensity then
			if vrRotationIntensity == "Low" then
				return VR_LOW_INTENSITY_ROTATION
			elseif vrRotationIntensity == "High" then
				return VR_HIGH_INTENSITY_ROTATION
			end
		end

		return ZERO_VECTOR2
	end
	function BaseCamera:GetRepeatDelayValue(vrRotationIntensity)
		vrRotationIntensity = vrRotationIntensity or StarterGui:GetCore("VRRotationIntensity")

		if vrRotationIntensity then
			if vrRotationIntensity == "Low" then
				return VR_LOW_INTENSITY_REPEAT
			elseif vrRotationIntensity == "High" then
				return VR_HIGH_INTENSITY_REPEAT
			end
		end

		return 0
	end
end

return BaseCamera
