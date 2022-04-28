-- # selene: allow(unused_variable)
-- # selene: allow(shadowing)
-- # selene: allow(incorrect_standard_library_use)

local PlayersService = game:GetService("Players")
local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local USE_STACKING_TRANSPARENCY = true
local TARGET_TRANSPARENCY = 0.75
local TARGET_TRANSPARENCY_PERIPHERAL = 0.5
local MODE = {
	LIMBS = 2,
	MOVEMENT = 3,
	CORNERS = 4,
	CIRCLE1 = 5,
	CIRCLE2 = 6,
	LIMBMOVE = 7,
	SMART_CIRCLE = 8,
	CHAR_OUTLINE = 9,
}
local LIMB_TRACKING_SET = {
	["Head"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	["LeftLowerArm"] = true,
	["RightLowerArm"] = true,
	["LeftUpperLeg"] = true,
	["RightUpperLeg"] = true,
}
local CORNER_FACTORS = {
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
}
local CIRCLE_CASTS = 10
local MOVE_CASTS = 3
local SMART_CIRCLE_CASTS = 24
local SMART_CIRCLE_INCREMENT = 2 * math.pi / SMART_CIRCLE_CASTS
local CHAR_OUTLINE_CASTS = 24

local function AssertTypes(param, ...)
	local allowedTypes = {}
	local typeString = ""

	for _, typeName in pairs({ ... }) do
		allowedTypes[typeName] = true
		typeString = typeString .. (typeString == "" and "" or " or ") .. typeName
	end

	local theType = type(param)

	assert(allowedTypes[theType], typeString .. " type expected, got: " .. theType)
end
local function Det3x3(a, b, c, d, e, f, g, h, i)
	return (a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g))
end
local function RayIntersection(p0, v0, p1, v1)
	local v2 = v0:Cross(v1)
	local d1 = p1.x - p0.x
	local d2 = p1.y - p0.y
	local d3 = p1.z - p0.z
	local denom = Det3x3(v0.x, -v1.x, v2.x, v0.y, -v1.y, v2.y, v0.z, -v1.z, v2.z)

	if denom == 0 then
		return ZERO_VECTOR3
	end

	local t0 = Det3x3(d1, -v1.x, v2.x, d2, -v1.y, v2.y, d3, -v1.z, v2.z) / denom
	local t1 = Det3x3(v0.x, d1, v2.x, v0.y, d2, v2.y, v0.z, d3, v2.z) / denom
	local s0 = p0 + t0 * v0
	local s1 = p1 + t1 * v1
	local s = s0 + 0.5 * (s1 - s0)

	if (s1 - s0).Magnitude < 0.25 then
		return s
	else
		return ZERO_VECTOR3
	end
end

local BaseOcclusion = require(script.Parent:WaitForChild("BaseOcclusion"))
local Invisicam = setmetatable({}, BaseOcclusion)

Invisicam.__index = Invisicam

function Invisicam.new()
	local self = setmetatable(BaseOcclusion.new(), Invisicam)

	self.char = nil
	self.humanoidRootPart = nil
	self.torsoPart = nil
	self.headPart = nil
	self.childAddedConn = nil
	self.childRemovedConn = nil
	self.behaviors = {}
	self.behaviors[MODE.LIMBS] = self.LimbBehavior
	self.behaviors[MODE.MOVEMENT] = self.MoveBehavior
	self.behaviors[MODE.CORNERS] = self.CornerBehavior
	self.behaviors[MODE.CIRCLE1] = self.CircleBehavior
	self.behaviors[MODE.CIRCLE2] = self.CircleBehavior
	self.behaviors[MODE.LIMBMOVE] = self.LimbMoveBehavior
	self.behaviors[MODE.SMART_CIRCLE] = self.SmartCircleBehavior
	self.behaviors[MODE.CHAR_OUTLINE] = self.CharacterOutlineBehavior
	self.mode = MODE.SMART_CIRCLE
	self.behaviorFunction = self.SmartCircleBehavior
	self.savedHits = {}
	self.trackedLimbs = {}
	self.camera = game.Workspace.CurrentCamera
	self.enabled = false

	return self
end
function Invisicam:Enable(enable)
	self.enabled = enable

	if not enable then
		self:Cleanup()
	end
end
function Invisicam:GetOcclusionMode()
	return Enum.DevCameraOcclusionMode.Invisicam
end
function Invisicam:LimbBehavior(castPoints)
	for limb, _ in pairs(self.trackedLimbs) do
		castPoints[#castPoints + 1] = limb.Position
	end
end
function Invisicam:MoveBehavior(castPoints)
	for i = 1, MOVE_CASTS do
		local position, velocity = self.humanoidRootPart.Position, self.humanoidRootPart.Velocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude / 2
		local offsetVector = (i - 1) * self.humanoidRootPart.CFrame.lookVector * horizontalSpeed

		castPoints[#castPoints + 1] = position + offsetVector
	end
end
function Invisicam:CornerBehavior(castPoints)
	local cframe = self.humanoidRootPart.CFrame
	local centerPoint = cframe.p
	local rotation = cframe - centerPoint
	local halfSize = self.char:GetExtentsSize() / 2

	castPoints[#castPoints + 1] = centerPoint

	for i = 1, #CORNER_FACTORS do
		castPoints[#castPoints + 1] = centerPoint + (rotation * (halfSize * CORNER_FACTORS[i]))
	end
end
function Invisicam:CircleBehavior(castPoints)
	local cframe

	if self.mode == MODE.CIRCLE1 then
		cframe = self.humanoidRootPart.CFrame
	else
		local camCFrame = self.camera.CoordinateFrame

		cframe = camCFrame - camCFrame.p + self.humanoidRootPart.Position
	end

	castPoints[#castPoints + 1] = cframe.p

	for i = 0, CIRCLE_CASTS - 1 do
		local angle = (2 * math.pi / CIRCLE_CASTS) * i
		local offset = 3 * Vector3.new(math.cos(angle), math.sin(angle), 0)

		castPoints[#castPoints + 1] = cframe * offset
	end
end
function Invisicam:LimbMoveBehavior(castPoints)
	self:LimbBehavior(castPoints)
	self:MoveBehavior(castPoints)
end
function Invisicam:CharacterOutlineBehavior(castPoints)
	local torsoUp = self.torsoPart.CFrame.upVector.unit
	local torsoRight = self.torsoPart.CFrame.rightVector.unit

	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p + torsoUp
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p - torsoUp
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p + torsoRight
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p - torsoRight

	if self.headPart then
		castPoints[#castPoints + 1] = self.headPart.CFrame.p
	end

	local cframe = CFrame.new(
		ZERO_VECTOR3,
		Vector3.new(self.camera.CoordinateFrame.lookVector.X, 0, self.camera.CoordinateFrame.lookVector.Z)
	)
	local centerPoint = (self.torsoPart and self.torsoPart.Position or self.humanoidRootPart.Position)
	local partsWhitelist = {
		self.torsoPart,
	}

	if self.headPart then
		partsWhitelist[#partsWhitelist + 1] = self.headPart
	end

	for i = 1, CHAR_OUTLINE_CASTS do
		local angle = (2 * math.pi * i / CHAR_OUTLINE_CASTS)
		local offset = cframe * (3 * Vector3.new(math.cos(angle), math.sin(angle), 0))

		offset = Vector3.new(offset.X, math.max(offset.Y, -2.25), offset.Z)

		local ray = Ray.new(centerPoint + offset, -3 * offset)
		local hit, hitPoint = game.Workspace:FindPartOnRayWithWhitelist(ray, partsWhitelist, false, false)

		if hit then
			castPoints[#castPoints + 1] = hitPoint + 0.2 * (centerPoint - hitPoint).unit
		end
	end
end
function Invisicam:SmartCircleBehavior(castPoints)
	local torsoUp = self.torsoPart.CFrame.upVector.unit
	local torsoRight = self.torsoPart.CFrame.rightVector.unit

	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p + torsoUp
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p - torsoUp
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p + torsoRight
	castPoints[#castPoints + 1] = self.torsoPart.CFrame.p - torsoRight

	if self.headPart then
		castPoints[#castPoints + 1] = self.headPart.CFrame.p
	end

	local cameraOrientation = self.camera.CFrame - self.camera.CFrame.p
	local torsoPoint = Vector3.new(0, 0.5, 0)
		+ (self.torsoPart and self.torsoPart.Position or self.humanoidRootPart.Position)
	local radius = 2.5

	for i = 1, SMART_CIRCLE_CASTS do
		local angle = SMART_CIRCLE_INCREMENT * i - 0.5 * math.pi
		local offset = radius * Vector3.new(math.cos(angle), math.sin(angle), 0)
		local circlePoint = torsoPoint + cameraOrientation * offset
		local vp = circlePoint - self.camera.CFrame.p
		local ray = Ray.new(torsoPoint, circlePoint - torsoPoint)
		local hit, hp, hitNormal = game.Workspace:FindPartOnRayWithIgnoreList(ray, {
			self.char,
		}, false, false)
		local castPoint = circlePoint

		if hit then
			local hprime = hp + 0.1 * hitNormal.unit
			local v0 = hprime - torsoPoint
			local perp = (v0:Cross(vp)).unit
			local v1 = (perp:Cross(hitNormal)).unit
			local vprime = (hprime - self.camera.CFrame.p).unit

			if v0.unit:Dot(-v1) < v0.unit:Dot(vprime) then
				castPoint = RayIntersection(hprime, v1, circlePoint, vp)

				if castPoint.Magnitude > 0 then
					local ray = Ray.new(hprime, castPoint - hprime)
					local hit, hitPoint, hitNormal = game.Workspace:FindPartOnRayWithIgnoreList(ray, {
						self.char,
					}, false, false)

					if hit then
						local hprime2 = hitPoint + 0.1 * hitNormal.unit

						castPoint = hprime2
					end
				else
					castPoint = hprime
				end
			else
				castPoint = hprime
			end

			local ray = Ray.new(torsoPoint, (castPoint - torsoPoint))
			local hit, hitPoint, hitNormal = game.Workspace:FindPartOnRayWithIgnoreList(ray, {
				self.char,
			}, false, false)

			if hit then
				local castPoint2 = hitPoint - 0.1 * (castPoint - torsoPoint).unit

				castPoint = castPoint2
			end
		end

		castPoints[#castPoints + 1] = castPoint
	end
end
function Invisicam:CheckTorsoReference()
	if self.char then
		self.torsoPart = self.char:FindFirstChild("Torso")

		if not self.torsoPart then
			self.torsoPart = self.char:FindFirstChild("UpperTorso")

			if not self.torsoPart then
				self.torsoPart = self.char:FindFirstChild("HumanoidRootPart")
			end
		end

		self.headPart = self.char:FindFirstChild("Head")
	end
end
function Invisicam:CharacterAdded(char, player)
	if player ~= PlayersService.LocalPlayer then
		return
	end
	if self.childAddedConn then
		self.childAddedConn:Disconnect()

		self.childAddedConn = nil
	end
	if self.childRemovedConn then
		self.childRemovedConn:Disconnect()

		self.childRemovedConn = nil
	end

	self.char = char
	self.trackedLimbs = {}

	local function childAdded(child)
		if child:IsA("BasePart") then
			if LIMB_TRACKING_SET[child.Name] then
				self.trackedLimbs[child] = true
			end
			if child.Name == "Torso" or child.Name == "UpperTorso" then
				self.torsoPart = child
			end
			if child.Name == "Head" then
				self.headPart = child
			end
		end
	end
	local function childRemoved(child)
		self.trackedLimbs[child] = nil

		self:CheckTorsoReference()
	end

	self.childAddedConn = char.ChildAdded:Connect(childAdded)
	self.childRemovedConn = char.ChildRemoved:Connect(childRemoved)

	for _, child in pairs(self.char:GetChildren()) do
		childAdded(child)
	end
end
function Invisicam:SetMode(newMode)
	AssertTypes(newMode, "number")

	for _, modeNum in pairs(MODE) do
		if modeNum == newMode then
			self.mode = newMode
			self.behaviorFunction = self.behaviors[self.mode]

			return
		end
	end

	error("Invalid mode number")
end
function Invisicam:GetObscuredParts()
	return self.savedHits
end
function Invisicam:Cleanup()
	for hit, originalFade in pairs(self.savedHits) do
		hit.LocalTransparencyModifier = originalFade
	end
end
function Invisicam:Update(dt, desiredCameraCFrame, desiredCameraFocus)
	if not self.enabled or not self.char then
		return desiredCameraCFrame, desiredCameraFocus
	end

	self.camera = game.Workspace.CurrentCamera

	if not self.humanoidRootPart then
		local humanoid = self.char:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.RootPart then
			self.humanoidRootPart = humanoid.RootPart
		else
			self.humanoidRootPart = self.char:FindFirstChild("HumanoidRootPart")

			if not self.humanoidRootPart then
				return desiredCameraCFrame, desiredCameraFocus
			end
		end

		local ancestryChangedConn

		ancestryChangedConn = self.humanoidRootPart.AncestryChanged:Connect(function(child, parent)
			if child == self.humanoidRootPart and not parent then
				self.humanoidRootPart = nil

				if ancestryChangedConn and ancestryChangedConn.Connected then
					ancestryChangedConn:Disconnect()

					ancestryChangedConn = nil
				end
			end
		end)
	end
	if not self.torsoPart then
		self:CheckTorsoReference()

		if not self.torsoPart then
			return desiredCameraCFrame, desiredCameraFocus
		end
	end

	local castPoints = {}

	self.behaviorFunction(self, castPoints)

	local currentHits = {}
	local ignoreList = {
		self.char,
	}

	local function add(hit)
		currentHits[hit] = true

		if not self.savedHits[hit] then
			self.savedHits[hit] = hit.LocalTransparencyModifier
		end
	end

	local hitParts
	local hitPartCount = 0
	local headTorsoRayHitParts = {}
	local perPartTransparencyHeadTorsoHits = TARGET_TRANSPARENCY
	local perPartTransparencyOtherHits = TARGET_TRANSPARENCY

	if USE_STACKING_TRANSPARENCY then
		local headPoint = self.headPart and self.headPart.CFrame.p or castPoints[1]
		local torsoPoint = self.torsoPart and self.torsoPart.CFrame.p or castPoints[2]

		hitParts = self.camera:GetPartsObscuringTarget({ headPoint, torsoPoint }, ignoreList)

		for i = 1, #hitParts do
			local hitPart = hitParts[i]

			hitPartCount = hitPartCount + 1
			headTorsoRayHitParts[hitPart] = true

			for _, child in pairs(hitPart:GetChildren()) do
				if child:IsA("Decal") or child:IsA("Texture") then
					hitPartCount = hitPartCount + 1

					break
				end
			end
		end

		if hitPartCount > 0 then
			perPartTransparencyHeadTorsoHits = math.pow(
				((0.5 * TARGET_TRANSPARENCY) + (0.5 * TARGET_TRANSPARENCY / hitPartCount)),
				1 / hitPartCount
			)
			perPartTransparencyOtherHits = math.pow(
				((0.5 * TARGET_TRANSPARENCY_PERIPHERAL) + (0.5 * TARGET_TRANSPARENCY_PERIPHERAL / hitPartCount)),
				1 / hitPartCount
			)
		end
	end

	hitParts = self.camera:GetPartsObscuringTarget(castPoints, ignoreList)

	local partTargetTransparency = {}

	for i = 1, #hitParts do
		local hitPart = hitParts[i]

		partTargetTransparency[hitPart] = headTorsoRayHitParts[hitPart] and perPartTransparencyHeadTorsoHits
			or perPartTransparencyOtherHits

		if hitPart.Transparency < partTargetTransparency[hitPart] then
			add(hitPart)
		end

		for _, child in pairs(hitPart:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				if child.Transparency < partTargetTransparency[hitPart] then
					partTargetTransparency[child] = partTargetTransparency[hitPart]

					add(child)
				end
			end
		end
	end

	for hitPart, originalLTM in pairs(self.savedHits) do
		if currentHits[hitPart] then
			hitPart.LocalTransparencyModifier = (hitPart.Transparency < 1)
					and ((partTargetTransparency[hitPart] - hitPart.Transparency) / (1 - hitPart.Transparency))
				or 0
		else
			hitPart.LocalTransparencyModifier = originalLTM
			self.savedHits[hitPart] = nil
		end
	end

	return desiredCameraCFrame, desiredCameraFocus
end

return Invisicam
