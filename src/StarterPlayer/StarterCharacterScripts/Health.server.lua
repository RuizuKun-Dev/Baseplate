local REGEN_RATE = 1E-2
local REGEN_STEP = 1
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

while true do
	while Humanoid.Health < Humanoid.MaxHealth do
		local dt = wait(REGEN_STEP)
		local dh = dt * REGEN_RATE * Humanoid.MaxHealth

		Humanoid.Health = math.min(Humanoid.Health + dh, Humanoid.MaxHealth)
	end

	Humanoid.HealthChanged:Wait()
end
