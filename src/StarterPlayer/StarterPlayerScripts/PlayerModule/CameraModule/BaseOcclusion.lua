local BaseOcclusion = {}

BaseOcclusion.__index = BaseOcclusion

setmetatable(BaseOcclusion, {
	__call = function(_, ...)
		return BaseOcclusion.new(...)
	end,
})

function BaseOcclusion.new()
	local self = setmetatable({}, BaseOcclusion)

	return self
end
function BaseOcclusion:CharacterAdded(char, player) end
function BaseOcclusion:CharacterRemoving(char, player) end
function BaseOcclusion:OnCameraSubjectChanged(newSubject) end
function BaseOcclusion:GetOcclusionMode()
	warn([[BaseOcclusion GetOcclusionMode must be overridden by derived classes]])

	return nil
end
function BaseOcclusion:Enable(enabled)
	warn("BaseOcclusion Enable must be overridden by derived classes")
end
function BaseOcclusion:Update(dt, desiredCameraCFrame, desiredCameraFocus)
	warn("BaseOcclusion Update must be overridden by derived classes")

	return desiredCameraCFrame, desiredCameraFocus
end

return BaseOcclusion
