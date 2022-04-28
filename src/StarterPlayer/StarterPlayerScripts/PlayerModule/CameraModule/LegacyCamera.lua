-- # selene: allow(unused_variable)

local ZERO_VECTOR2 = Vector2.new()
local PITCH_LIMIT = math.rad(80)
local Util = require(script.Parent:WaitForChild("CameraUtils"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local PlayersService = game:GetService("Players")
local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local LegacyCamera = setmetatable({}, BaseCamera)

LegacyCamera.__index = LegacyCamera

function LegacyCamera.new()
	local self = setmetatable(BaseCamera.new(), LegacyCamera)

	self.cameraType = Enum.CameraType.Fixed
	self.lastUpdate = tick()
	self.lastDistanceToSubject = nil

	return self
end
function LegacyCamera:GetModuleName()
	return "LegacyCamera"
end
function LegacyCamera:SetCameraToSubjectDistance(desiredSubjectDistance)
	return BaseCamera.SetCameraToSubjectDistance(self, desiredSubjectDistance)
end
function LegacyCamera:Update(dt)
	if not self.cameraType then
		return
	end

	local now = tick()
	local timeDelta = (now - self.lastUpdate)
	local camera = workspace.CurrentCamera
	local newCameraCFrame = camera.CFrame
	local newCameraFocus = camera.Focus
	local player = PlayersService.LocalPlayer

	if self.lastUpdate == nil or timeDelta > 1 then
		self.lastDistanceToSubject = nil
	end

	local subjectPosition = self:GetSubjectPosition()

	if self.cameraType == Enum.CameraType.Fixed then
		if subjectPosition and player and camera then
			local distanceToSubject = self:GetCameraToSubjectDistance()
			local newLookVector = self:CalculateNewLookVectorFromArg(nil, CameraInput.getRotation())

			newCameraFocus = camera.Focus
			newCameraCFrame = CFrame.new(camera.CFrame.p, camera.CFrame.p + (distanceToSubject * newLookVector))
		end
	elseif self.cameraType == Enum.CameraType.Attach then
		local subjectCFrame = self:GetSubjectCFrame()
		local cameraPitch = camera.CFrame:ToEulerAnglesYXZ()
		local _, subjectYaw = subjectCFrame:ToEulerAnglesYXZ()

		cameraPitch = math.clamp(cameraPitch - CameraInput.getRotation().Y, -PITCH_LIMIT, PITCH_LIMIT)
		newCameraFocus = CFrame.new(subjectCFrame.p) * CFrame.fromEulerAnglesYXZ(cameraPitch, subjectYaw, 0)
		newCameraCFrame = newCameraFocus * CFrame.new(0, 0, self:StepZoom())
	elseif self.cameraType == Enum.CameraType.Watch then
		if subjectPosition and player and camera then
			local cameraLook = nil

			if subjectPosition == camera.CFrame.p then
				warn("Camera cannot watch subject in same position as itself")

				return camera.CFrame, camera.Focus
			end

			local humanoid = self:GetHumanoid()

			if humanoid and humanoid.RootPart then
				local diffVector = subjectPosition - camera.CFrame.p

				cameraLook = diffVector.unit

				if self.lastDistanceToSubject and self.lastDistanceToSubject == self:GetCameraToSubjectDistance() then
					local newDistanceToSubject = diffVector.magnitude

					self:SetCameraToSubjectDistance(newDistanceToSubject)
				end
			end

			local distanceToSubject = self:GetCameraToSubjectDistance()
			local newLookVector = self:CalculateNewLookVectorFromArg(cameraLook, CameraInput.getRotation())

			newCameraFocus = CFrame.new(subjectPosition)
			newCameraCFrame = CFrame.new(subjectPosition - (distanceToSubject * newLookVector), subjectPosition)
			self.lastDistanceToSubject = distanceToSubject
		end
	else
		return camera.CFrame, camera.Focus
	end

	self.lastUpdate = now

	return newCameraCFrame, newCameraFocus
end

return LegacyCamera
