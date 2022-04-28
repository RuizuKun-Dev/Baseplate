local ZERO_VECTOR2 = Vector2.new(0, 0)
local tweenAcceleration = math.rad(220)
local tweenSpeed = math.rad(0)
local tweenMaxSpeed = math.rad(250)
local TIME_BEFORE_AUTO_ROTATE = 2
local INITIAL_CAMERA_ANGLE = CFrame.fromOrientation(math.rad(-15), 0, 0)
local ZOOM_SENSITIVITY_CURVATURE = 0.5
local FIRST_PERSON_DISTANCE_MIN = 0.5
local PlayersService = game:GetService('Players')
local VRService = game:GetService('VRService')
local CameraInput = require(script.Parent:WaitForChild('CameraInput'))
local Util = require(script.Parent:WaitForChild('CameraUtils'))
local BaseCamera = require(script.Parent:WaitForChild('BaseCamera'))
local ClassicCamera = setmetatable({}, BaseCamera)

ClassicCamera.__index = ClassicCamera

function ClassicCamera.new()
    local self = setmetatable(BaseCamera.new(), ClassicCamera)

    self.isFollowCamera = false
    self.isCameraToggle = false
    self.lastUpdate = tick()
    self.cameraToggleSpring = Util.Spring.new(5, 0)

    return self
end
function ClassicCamera:GetCameraToggleOffset(dt)
    if self.isCameraToggle then
        local zoom = self.currentSubjectDistance

        if CameraInput.getTogglePan() then
            self.cameraToggleSpring.goal = math.clamp(Util.map(zoom, 0.5, self.FIRST_PERSON_DISTANCE_THRESHOLD, 0, 1), 0, 1)
        else
            self.cameraToggleSpring.goal = 0
        end

        local distanceOffset = math.clamp(Util.map(zoom, 0.5, 64, 0, 1), 0, 1) + 1

        return Vector3.new(0, self.cameraToggleSpring:step(dt) * distanceOffset, 0)
    end

    return Vector3.new()
end
function ClassicCamera:SetCameraMovementMode(cameraMovementMode)
    BaseCamera.SetCameraMovementMode(self, cameraMovementMode)

    self.isFollowCamera = cameraMovementMode == Enum.ComputerCameraMovementMode.Follow
    self.isCameraToggle = cameraMovementMode == Enum.ComputerCameraMovementMode.CameraToggle
end
function ClassicCamera:Update()
    local now = tick()
    local timeDelta = now - self.lastUpdate
    local camera = workspace.CurrentCamera
    local newCameraCFrame = camera.CFrame
    local newCameraFocus = camera.Focus
    local overrideCameraLookVector = nil

    if self.resetCameraAngle then
        local rootPart = self:GetHumanoidRootPart()

        if rootPart then
            overrideCameraLookVector = (rootPart.CFrame * INITIAL_CAMERA_ANGLE).lookVector
        else
            overrideCameraLookVector = INITIAL_CAMERA_ANGLE.lookVector
        end

        self.resetCameraAngle = false
    end

    local player = PlayersService.LocalPlayer
    local humanoid = self:GetHumanoid()
    local cameraSubject = camera.CameraSubject
    local isInVehicle = cameraSubject and cameraSubject:IsA('VehicleSeat')
    local isOnASkateboard = cameraSubject and cameraSubject:IsA('SkateboardPlatform')
    local isClimbing = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Climbing

    if self.lastUpdate == nil or timeDelta > 1 then
        self.lastCameraTransform = nil
    end

    local rotateInput = CameraInput.getRotation()

    self:StepZoom()

    local cameraHeight = self:GetCameraHeight()

    if CameraInput.getRotation() ~= Vector2.new() then
        tweenSpeed = 0
        self.lastUserPanCamera = tick()
    end

    local userRecentlyPannedCamera = now - self.lastUserPanCamera < TIME_BEFORE_AUTO_ROTATE
    local subjectPosition = self:GetSubjectPosition()

    if subjectPosition and player and camera then
        local zoom = self:GetCameraToSubjectDistance()

        if zoom < 0.5 then
            zoom = 0.5
        end
        if self:GetIsMouseLocked() and not self:IsInFirstPerson() then
            local newLookCFrame = self:CalculateNewLookCFrameFromArg(overrideCameraLookVector, rotateInput)
            local offset = self:GetMouseLockOffset()
            local cameraRelativeOffset = offset.X * newLookCFrame.rightVector + offset.Y * newLookCFrame.upVector + offset.Z * newLookCFrame.lookVector

            if Util.IsFiniteVector3(cameraRelativeOffset) then
                subjectPosition = subjectPosition + cameraRelativeOffset
            end
        else
            local userPanningTheCamera = CameraInput.getRotation() ~= Vector2.new()

            if not userPanningTheCamera and self.lastCameraTransform then
                local isInFirstPerson = self:IsInFirstPerson()

                if (isInVehicle or isOnASkateboard or (self.isFollowCamera and isClimbing)) and self.lastUpdate and humanoid and humanoid.Torso then
                    if isInFirstPerson then
                        if self.lastSubjectCFrame and (isInVehicle or isOnASkateboard) and cameraSubject:IsA('BasePart') then
                            local y = -Util.GetAngleBetweenXZVectors(self.lastSubjectCFrame.lookVector, cameraSubject.CFrame.lookVector)

                            if Util.IsFinite(y) then
                                rotateInput = rotateInput + Vector2.new(y, 0)
                            end

                            tweenSpeed = 0
                        end
                    elseif not userRecentlyPannedCamera then
                        local forwardVector = humanoid.Torso.CFrame.lookVector

                        tweenSpeed = math.clamp(tweenSpeed + tweenAcceleration * timeDelta, 0, tweenMaxSpeed)

                        local percent = math.clamp(tweenSpeed * timeDelta, 0, 1)

                        if self:IsInFirstPerson() and not (self.isFollowCamera and self.isClimbing) then
                            percent = 1
                        end

                        local y = Util.GetAngleBetweenXZVectors(forwardVector, self:GetCameraLookVector())

                        if Util.IsFinite(y) and math.abs(y) > 0.0001 then
                            rotateInput = rotateInput + Vector2.new(y * percent, 0)
                        end
                    end
                elseif self.isFollowCamera and (not (isInFirstPerson or userRecentlyPannedCamera) and not VRService.VREnabled) then
                    local lastVec = -(self.lastCameraTransform.p - subjectPosition)
                    local y = Util.GetAngleBetweenXZVectors(lastVec, self:GetCameraLookVector())
                    local thetaCutoff = 0.4

                    if Util.IsFinite(y) and math.abs(y) > 0.0001 and math.abs(y) > thetaCutoff * timeDelta then
                        rotateInput = rotateInput + Vector2.new(y, 0)
                    end
                end
            end
        end
        if not self.isFollowCamera then
            local VREnabled = VRService.VREnabled

            if VREnabled then
                newCameraFocus = self:GetVRFocus(subjectPosition, timeDelta)
            else
                newCameraFocus = CFrame.new(subjectPosition)
            end

            local cameraFocusP = newCameraFocus.p

            if VREnabled and not self:IsInFirstPerson() then
                local vecToSubject = (subjectPosition - camera.CFrame.p)
                local distToSubject = vecToSubject.magnitude
                local flaggedRotateInput = rotateInput

                if distToSubject > zoom or flaggedRotateInput.x ~= 0 then
                    local desiredDist = math.min(distToSubject, zoom)

                    vecToSubject = self:CalculateNewLookVectorFromArg(nil, rotateInput) * desiredDist

                    local newPos = cameraFocusP - vecToSubject
                    local desiredLookDir = camera.CFrame.lookVector

                    if flaggedRotateInput.x ~= 0 then
                        desiredLookDir = vecToSubject
                    end

                    local lookAt = Vector3.new(newPos.x + desiredLookDir.x, newPos.y, newPos.z + desiredLookDir.z)

                    newCameraCFrame = CFrame.new(newPos, lookAt) + Vector3.new(0, cameraHeight, 0)
                end
            else
                local newLookVector = self:CalculateNewLookVectorFromArg(overrideCameraLookVector, rotateInput)

                newCameraCFrame = CFrame.new(cameraFocusP - (zoom * newLookVector), cameraFocusP)
            end
        else
            local newLookVector = self:CalculateNewLookVectorFromArg(overrideCameraLookVector, rotateInput)

            if VRService.VREnabled then
                newCameraFocus = self:GetVRFocus(subjectPosition, timeDelta)
            else
                newCameraFocus = CFrame.new(subjectPosition)
            end

            newCameraCFrame = CFrame.new(newCameraFocus.p - (zoom * newLookVector), newCameraFocus.p) + Vector3.new(0, cameraHeight, 0)
        end

        local toggleOffset = self:GetCameraToggleOffset(timeDelta)

        newCameraFocus = newCameraFocus + toggleOffset
        newCameraCFrame = newCameraCFrame + toggleOffset
        self.lastCameraTransform = newCameraCFrame
        self.lastCameraFocus = newCameraFocus

        if (isInVehicle or isOnASkateboard) and cameraSubject:IsA('BasePart') then
            self.lastSubjectCFrame = cameraSubject.CFrame
        else
            self.lastSubjectCFrame = nil
        end
    end

    self.lastUpdate = now

    return newCameraCFrame, newCameraFocus
end
function ClassicCamera:EnterFirstPerson()
    self.inFirstPerson = true

    self:UpdateMouseBehavior()
end
function ClassicCamera:LeaveFirstPerson()
    self.inFirstPerson = false

    self:UpdateMouseBehavior()
end

return ClassicCamera
