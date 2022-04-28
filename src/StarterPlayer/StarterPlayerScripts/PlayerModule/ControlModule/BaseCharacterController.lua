local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local BaseCharacterController = {}

BaseCharacterController.__index = BaseCharacterController

function BaseCharacterController.new()
	local self = setmetatable({}, BaseCharacterController)

	self.enabled = false
	self.moveVector = ZERO_VECTOR3
	self.moveVectorIsCameraRelative = true
	self.isJumping = false

	return self
end
function BaseCharacterController:OnRenderStepped(dt) end
function BaseCharacterController:GetMoveVector()
	return self.moveVector
end
function BaseCharacterController:IsMoveVectorCameraRelative()
	return self.moveVectorIsCameraRelative
end
function BaseCharacterController:GetIsJumping()
	return self.isJumping
end
function BaseCharacterController:Enable(enable)
	error([[BaseCharacterController:Enable must be overridden in derived classes and should not be called.]])

	return false
end

return BaseCharacterController
