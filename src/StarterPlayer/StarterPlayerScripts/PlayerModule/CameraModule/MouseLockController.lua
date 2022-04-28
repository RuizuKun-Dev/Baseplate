-- # selene: allow(unused_variable)


local DEFAULT_MOUSE_LOCK_CURSOR = "rbxasset://textures/MouseLockedCursor.png"

local CONTEXT_ACTION_NAME = "MouseLockSwitchAction"
local MOUSELOCK_ACTION_PRIORITY = Enum.ContextActionPriority.Default.Value

local FFlagUserCameraToggleDontSetMouseIconEveryFrame
do
	local success, value = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserCameraToggleDontSetMouseIconEveryFrame")
	end)
	FFlagUserCameraToggleDontSetMouseIconEveryFrame = success and value
end


local PlayersService = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local Settings = UserSettings() -- ignore warning
local GameSettings = Settings.GameSettings
local Mouse = if FFlagUserCameraToggleDontSetMouseIconEveryFrame then nil else PlayersService.LocalPlayer:GetMouse()


local CameraUtils = if FFlagUserCameraToggleDontSetMouseIconEveryFrame
	then require(script.Parent:WaitForChild("CameraUtils"))
	else nil


local MouseLockController = {}
MouseLockController.__index = MouseLockController

function MouseLockController.new()
	local self = setmetatable({}, MouseLockController)

	self.isMouseLocked = false
	self.savedMouseCursor = nil
	self.boundKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }

	self.mouseLockToggledEvent = Instance.new("BindableEvent")

	local boundKeysObj: StringValue = script:FindFirstChild("BoundKeys") :: StringValue
	if not boundKeysObj or (not boundKeysObj:IsA("StringValue")) then

		if boundKeysObj then
			boundKeysObj:Destroy()
		end

		boundKeysObj = Instance.new("StringValue")
		boundKeysObj.Name = "BoundKeys"
		boundKeysObj.Value = "LeftShift,RightShift"
		boundKeysObj.Parent = script
	end

	if boundKeysObj then
		boundKeysObj.Changed:Connect(function(value)
			self:OnBoundKeysObjectChanged(value)
		end)
		self:OnBoundKeysObjectChanged(boundKeysObj.Value)
	end

	
	GameSettings.Changed:Connect(function(property)
		if property == "ControlMode" or property == "ComputerMovementMode" then
			self:UpdateMouseLockAvailability()
		end
	end)

	
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	self:UpdateMouseLockAvailability()

	return self
end

function MouseLockController:GetIsMouseLocked()
	return self.isMouseLocked
end

function MouseLockController:GetBindableToggleEvent()
	return self.mouseLockToggledEvent.Event
end

function MouseLockController:GetMouseLockOffset()
	local offsetValueObj: Vector3Value = script:FindFirstChild("CameraOffset") :: Vector3Value
	if offsetValueObj and offsetValueObj:IsA("Vector3Value") then
		return offsetValueObj.Value
	else
		
		if offsetValueObj then
			offsetValueObj:Destroy()
		end
		offsetValueObj = Instance.new("Vector3Value")
		offsetValueObj.Name = "CameraOffset"
		offsetValueObj.Value = Vector3.new(1.75, 0, 0)
		offsetValueObj.Parent = script
	end

	if offsetValueObj and offsetValueObj.Value then
		return offsetValueObj.Value
	end

	return Vector3.new(1.75, 0, 0)
end

function MouseLockController:UpdateMouseLockAvailability()
	local devAllowsMouseLock = PlayersService.LocalPlayer.DevEnableMouseLock
	local devMovementModeIsScriptable = PlayersService.LocalPlayer.DevComputerMovementMode
		== Enum.DevComputerMovementMode.Scriptable
	local userHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	local userHasClickToMoveEnabled = GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local MouseLockAvailable = devAllowsMouseLock
		and userHasMouseLockModeEnabled
		and not userHasClickToMoveEnabled
		and not devMovementModeIsScriptable

	if MouseLockAvailable ~= self.enabled then
		self:EnableMouseLock(MouseLockAvailable)
	end
end

function MouseLockController:OnBoundKeysObjectChanged(newValue: string)
	self.boundKeys = {}
	for token in string.gmatch(newValue, "[^%s,]+") do
		for _, keyEnum in pairs(Enum.KeyCode:GetEnumItems()) do
			if token == keyEnum.Name then
				self.boundKeys[#self.boundKeys + 1] = keyEnum :: Enum.KeyCode
				break
			end
		end
	end
	self:UnbindContextActions()
	self:BindContextActions()
end


function MouseLockController:OnMouseLockToggled()
	self.isMouseLocked = not self.isMouseLocked

	if self.isMouseLocked then
		local cursorImageValueObj: StringValue = script:FindFirstChild("CursorImage") :: StringValue
		if cursorImageValueObj and cursorImageValueObj:IsA("StringValue") and cursorImageValueObj.Value then
			if FFlagUserCameraToggleDontSetMouseIconEveryFrame then
				CameraUtils.setMouseIconOverride(cursorImageValueObj.Value)
			else
				self.savedMouseCursor = Mouse.Icon
				Mouse.Icon = cursorImageValueObj.Value
			end
		else
			if cursorImageValueObj then
				cursorImageValueObj:Destroy()
			end
			cursorImageValueObj = Instance.new("StringValue")
			cursorImageValueObj.Name = "CursorImage"
			cursorImageValueObj.Value = DEFAULT_MOUSE_LOCK_CURSOR
			cursorImageValueObj.Parent = script
			if FFlagUserCameraToggleDontSetMouseIconEveryFrame then
				CameraUtils.setMouseIconOverride(DEFAULT_MOUSE_LOCK_CURSOR)
			else
				self.savedMouseCursor = Mouse.Icon
				Mouse.Icon = DEFAULT_MOUSE_LOCK_CURSOR
			end
		end
	else
		if FFlagUserCameraToggleDontSetMouseIconEveryFrame then
			CameraUtils.restoreMouseIcon()
		else
			if self.savedMouseCursor then
				Mouse.Icon = self.savedMouseCursor
				self.savedMouseCursor = nil
			end
		end
	end

	self.mouseLockToggledEvent:Fire()
end

function MouseLockController:DoMouseLockSwitch(name, state, input)
	if state == Enum.UserInputState.Begin then
		self:OnMouseLockToggled()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function MouseLockController:BindContextActions()
	ContextActionService:BindActionAtPriority(CONTEXT_ACTION_NAME, function(name, state, input)
		return self:DoMouseLockSwitch(name, state, input)
	end, false, MOUSELOCK_ACTION_PRIORITY, unpack(self.boundKeys))
end

function MouseLockController:UnbindContextActions()
	ContextActionService:UnbindAction(CONTEXT_ACTION_NAME)
end

function MouseLockController:IsMouseLocked(): boolean
	return self.enabled and self.isMouseLocked
end

function MouseLockController:EnableMouseLock(enable: boolean)
	if enable ~= self.enabled then
		self.enabled = enable

		if self.enabled then
			
			self:BindContextActions()
		else

			if FFlagUserCameraToggleDontSetMouseIconEveryFrame then
				CameraUtils.restoreMouseIcon()
			else
				if Mouse.Icon ~= "" then
					Mouse.Icon = ""
				end
			end

			self:UnbindContextActions()

			
			if self.isMouseLocked then
				self.mouseLockToggledEvent:Fire()
			end

			self.isMouseLocked = false
		end
	end
end

return MouseLockController
