--!strict
-- Arriving somewhere in the Depths (a new floor, the entrance, pulled into a fight): the server says where
-- ("Landing"), and this screen holds the character still right there until the floor under that spot has
-- arrived here, then lets go, so nobody drops through a floor that hasn't loaded yet.
-- And if the character ever falls far below the dungeon anyway, the server is told ("Fell") and puts it back
-- at the entrance instead of letting it die.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Landing = {}

local WAIT_FOR_FLOOR = 12 -- seconds at most to hold a player in the air
local FALL_Y = -80 -- below this, the character has fallen out of the dungeon

function Landing.Start()
	local player = Players.LocalPlayer
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local landing = 0 -- (a newer landing replaces an older one still waiting)

	Remotes.Event("Landing").OnClientEvent:Connect(function(target: any)
		if typeof(target) ~= "CFrame" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not root then
			return
		end
		landing += 1
		local mine = landing
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(target)
		local dungeon = workspace:WaitForChild("Dungeon", 5)
		if dungeon then
			params.FilterDescendantsInstances = { dungeon }
			local waited = 0
			while waited < WAIT_FOR_FLOOR and landing == mine do
				if workspace:Raycast(target.Position, Vector3.new(0, -30, 0), params) then
					break
				end
				waited += task.wait(0.1)
			end
			task.wait(0.25) -- (a moment for the walls and props around it too)
		end
		if landing == mine and root.Parent then
			character:PivotTo(target)
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = false
		end
	end)

	local fell = Remotes.Event("Fell")
	local lastTold = 0
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not root.Anchored and root.Position.Y < FALL_Y then
			local now = os.clock()
			if now - lastTold > 2 then
				lastTold = now
				fell:FireServer()
			end
		end
	end)
end

return Landing
