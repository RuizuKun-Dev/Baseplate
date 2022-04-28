local PlayerModule = {}

PlayerModule.__index = PlayerModule

function PlayerModule.new()
	local self = setmetatable({}, PlayerModule)

	self.cameras = require(script:WaitForChild("CameraModule"))
	self.controls = require(script:WaitForChild("ControlModule"))

	return self
end
function PlayerModule:GetCameras()
	return self.cameras
end
function PlayerModule:GetControls()
	return self.controls
end
function PlayerModule:GetClickToMoveController()
	return self.controls:GetClickToMoveController()
end

return PlayerModule.new()
