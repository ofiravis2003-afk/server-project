--!strict
-- Brings Elder Ember to life on this screen: he breathes and slowly beats his wings.
-- The server places him once (see server/Services/ElderService); moving him here costs no network.

local RunService = game:GetService("RunService")

local DragonAnimator = require(game:GetService("ReplicatedStorage").Shared.DragonAnimator)

local HOVER = 1.2 -- studs above his rock
local SLOWNESS = 0.45 -- of the normal idle wingbeat: he is old and calm
local DRAW_DISTANCE = 250

local ElderEffects = {}

function ElderEffects.Start()
	task.spawn(function()
		local island = workspace:WaitForChild("EmberIsle")
		local elder = island:WaitForChild("ElderEmber", 60)
		if not elder or not elder:IsA("Model") then
			return
		end
		local home = elder:GetAttribute("Home")
		if typeof(home) ~= "CFrame" then
			return
		end
		local rig = DragonAnimator.Rig(elder)
		local where = home + Vector3.new(0, HOVER, 0)
		local phase = 0
		RunService.RenderStepped:Connect(function(dt: number)
			local camera = workspace.CurrentCamera
			if not camera or (camera.CFrame.Position - where.Position).Magnitude > DRAW_DISTANCE then
				return
			end
			phase += dt * DragonAnimator.FlapSpeed(0) * SLOWNESS
			local parts, frames = DragonAnimator.Pose(rig, where, phase, 0)
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end)
end

return ElderEffects
