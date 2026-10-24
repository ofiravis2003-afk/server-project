--!strict
-- "The Deepest Descents": a stone board beside the Wall of the Fallen with the ten adventurers who have gone
-- deepest (shared Leaderboard), refreshed every minute. A player's own deepest floor is written down when they
-- arrive in town (so it counts even from before the board existed).

local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local Leaderboard = require(Common.Leaderboard)

local DepthsBoard = {}

local ROWS = 10
local REFRESH = 60
local GOLD = Color3.fromRGB(240, 190, 90)
local TEXT = Color3.fromRGB(230, 222, 208)
local STONE = Color3.fromRGB(58, 52, 50)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

function DepthsBoard.Start(town: { Model: Model })
	local wall = town.Model:FindFirstChild("WallOfTheFallen", true)
	if not wall or not wall:IsA("Model") then
		return
	end
	local box, size = wall:GetBoundingBox()
	local ground = box.Position.Y - size.Y / 2
	-- beside the Wall of the Fallen, the same way round
	local at = wall:GetPivot() * CFrame.new(14, 0, 0)
	local base = CFrame.new(at.Position.X, ground, at.Position.Z) * at.Rotation

	local model = Instance.new("Model")
	model.Name = "DeepestDescents"
	for _, side in { -1, 1 } do
		part(model, "Pillar", Vector3.new(1.2, 10, 1.2), base * CFrame.new(side * 6.6, 5, 0), STONE, Enum.Material.Cobblestone)
		local cap = part(model, "Brazier", Vector3.new(1.6, 0.6, 1.6), base * CFrame.new(side * 6.6, 10.3, 0), Color3.fromRGB(40, 32, 28), Enum.Material.CorrodedMetal)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 4
		fire.Parent = cap
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Range = 12
		light.Brightness = 1.2
		light.Parent = cap
	end
	local slab = part(model, "Slab", Vector3.new(12, 8.5, 0.8), base * CFrame.new(0, 5.2, 0), Color3.fromRGB(44, 38, 36), Enum.Material.Slate)
	model.Parent = town.Model

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- (the side facing the way the Wall faces)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = slab
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 52)
	title.Position = UDim2.fromOffset(0, 10)
	title.Font = Enum.Font.Fondamento
	title.TextSize = 44
	title.TextColor3 = GOLD
	title.Text = "The Deepest Descents"
	title.Parent = gui
	local lines = {}
	for i = 1, ROWS do
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.new(0, 30, 0, 66 + (i - 1) * 25)
		line.Size = UDim2.new(1, -60, 0, 24)
		line.Font = Enum.Font.GothamBold
		line.TextSize = 20
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = if i <= 3 then GOLD else TEXT
		line.Text = ""
		line.Parent = gui
		lines[i] = line
	end

	task.spawn(function()
		while model.Parent do
			local top = Leaderboard.Top(ROWS)
			if top then
				for i, line in lines do
					local entry = top[i]
					line.Text = if entry then `{i}.  {entry.Name}  —  Floor {entry.Floor}` else ""
				end
				if #top == 0 then
					lines[1].Text = "No one yet. Be the first to go down."
				end
			end
			task.wait(REFRESH)
		end
	end)

	DataService.OnLoaded(function(player, data)
		if (data.DeepestFloor or 0) > 0 then
			Leaderboard.Record(player, data.DeepestFloor)
		end
	end)
end

return DepthsBoard
