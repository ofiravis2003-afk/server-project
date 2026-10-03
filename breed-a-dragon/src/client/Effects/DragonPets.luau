--!strict
-- Draws every player's active dragons flying behind them, in a small size.
-- The server only publishes which dragons are active (player attribute "ActiveDragons");
-- each client builds and moves the models itself, so movement is smooth and uses no network.
-- DragonAnimator flaps the wings and sways the tail; running makes them flap faster and lean in.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonAnimator = require(ReplicatedStorage.Shared.DragonAnimator)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local Genes = require(ReplicatedStorage.Shared.Genes)

local FOLLOW_DISTANCE = 7 -- studs behind the player
local SPREAD = 0.55 -- radians between dragons in the arc
local HOVER_HEIGHT = -1 -- relative to the player's root (their waist)
local DRIFT_HEIGHT = 0.3 -- slow extra up-and-down so the dragons don't move in lockstep
local LEAN_ANGLE = math.rad(14) -- how far the dragons lean forward at full speed
local RUN_SPEED = 16 -- player speed counted as "flying fast"
local FOLLOW_SPEED = 6 -- higher = catches up faster
local DRAW_DISTANCE = 220 -- skip moving dragons that are far from the camera

type Pet = {
	Model: Model,
	Rig: DragonAnimator.Rig,
	Frame: CFrame,
	Phase: number,
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

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	local rig = DragonAnimator.Rig(model)
	model:PivotTo(start)
	model.Parent = folder
	-- Random starting wingbeat, so a group of dragons doesn't flap in perfect sync.
	return { Model = model, Rig = rig, Frame = start, Phase = math.random() * math.pi * 2 }
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
			local velocity = root.AssemblyLinearVelocity
			local effort = math.clamp(Vector3.new(velocity.X, 0, velocity.Z).Magnitude / RUN_SPEED, 0, 1)
			local count = #pets
			for i, pet in pets do
				-- Spread the dragons in an arc behind the player.
				local angle = (i - (count + 1) / 2) * SPREAD
				local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * FOLLOW_DISTANCE
				local position = root.CFrame:PointToWorldSpace(offset)
					+ Vector3.new(0, HOVER_HEIGHT + math.sin(now * 0.8 + i * 1.7) * DRIFT_HEIGHT, 0)
				local target = CFrame.lookAt(position, position + root.CFrame.LookVector)
					* CFrame.Angles(-LEAN_ANGLE * effort, 0, 0)
				pet.Frame = pet.Frame:Lerp(target, alpha)
				pet.Phase += dt * DragonAnimator.FlapSpeed(effort)

				local parts, frames = DragonAnimator.Pose(pet.Rig, pet.Frame, pet.Phase, effort)
				table.move(parts, 1, #parts, #allParts + 1, allParts)
				table.move(frames, 1, #frames, #allFrames + 1, allFrames)
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
