--!strict
-- Draws every player's active dragons flying behind them, in a small size.
-- The server only publishes which dragons are active (player attribute "ActiveDragons");
-- each client builds and moves the models itself, so movement is smooth and uses no network.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local Genes = require(ReplicatedStorage.Shared.Genes)

local FOLLOW_DISTANCE = 7 -- studs behind the player
local SPREAD = 0.55 -- radians between dragons in the arc
local HOVER_HEIGHT = -1 -- relative to the player's root (their waist)
local BOB_HEIGHT = 0.5
local FOLLOW_SPEED = 6 -- higher = catches up faster
local DRAW_DISTANCE = 220 -- skip moving dragons that are far from the camera

type Pet = {
	Model: Model,
	Parts: { BasePart },
	Offsets: { CFrame },
	Frame: CFrame,
}

local DragonPets = {}

local folder: Folder
local petsByPlayer: { [Player]: { Pet } } = {}

local function clear(player: Player)
	local pets = petsByPlayer[player]
	if pets then
		for _, pet in pets do
			pet.Model:Destroy()
		end
	end
	petsByPlayer[player] = nil
end

local function makePet(genes: Genes.DragonGenes, start: CFrame): Pet
	local model = DragonBuilder.Build(genes)
	model:ScaleTo(model:GetScale() * Config.Dragons.PetScale)

	local pivot = model:GetPivot()
	local parts, offsets = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
			part.CastShadow = false
			table.insert(parts, part)
			table.insert(offsets, pivot:ToObjectSpace(part.CFrame))
		end
	end
	model:PivotTo(start)
	model.Parent = folder
	return { Model = model, Parts = parts, Offsets = offsets, Frame = start }
end

local function rebuild(player: Player)
	clear(player)
	local raw = player:GetAttribute("ActiveDragons")
	if type(raw) ~= "string" then
		return
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(list) ~= "table" then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame else CFrame.new()

	local pets = {}
	for _, genes in list do
		if Genes.IsValid(genes) then
			table.insert(pets, makePet(genes, start))
		end
	end
	petsByPlayer[player] = pets
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("ActiveDragons"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local alpha = 1 - math.exp(-dt * FOLLOW_SPEED)
	local now = os.clock()

	local allParts: { BasePart } = {}
	local allFrames: { CFrame } = {}

	for player, pets in petsByPlayer do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - cameraPosition).Magnitude < DRAW_DISTANCE then
			local count = #pets
			for i, pet in pets do
				-- Spread the dragons in an arc behind the player, bobbing as if flying.
				local angle = (i - (count + 1) / 2) * SPREAD
				local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * FOLLOW_DISTANCE
				local position = root.CFrame:PointToWorldSpace(offset)
					+ Vector3.new(0, HOVER_HEIGHT + math.sin(now * 2 + i) * BOB_HEIGHT, 0)
				local target = CFrame.lookAt(position, position + root.CFrame.LookVector)
				pet.Frame = pet.Frame:Lerp(target, alpha)

				for index, part in pet.Parts do
					table.insert(allParts, part)
					table.insert(allFrames, pet.Frame * pet.Offsets[index])
				end
			end
		end
	end

	if #allParts > 0 then
		workspace:BulkMoveTo(allParts, allFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function DragonPets.Start()
	folder = Instance.new("Folder")
	folder.Name = "DragonPets"
	folder.Parent = workspace

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end

	RunService.RenderStepped:Connect(update)
end

return DragonPets
