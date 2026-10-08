--!strict
-- Runs the dungeon: builds each floor, locks combat rooms until their monsters are dead,
-- hands out keys, opens chests, works the secret lever and takes everyone down the stairs.
--
-- One Depths server is one run (solo, or a party later in stage 6), so the run's state
-- (current floor, keys in hand) lives here in memory. Keys are per player and only last the run.
-- Loot is per player too: everyone with the right key can open every chest once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Floors = require(ReplicatedStorage.Shared.Floors)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.Parent.Common.DataService)
local InventoryService = require(script.Parent.Parent.Common.InventoryService)
local ProgressService = require(script.Parent.Parent.Common.ProgressService)
local EnemyService = require(script.Parent.EnemyService)
local FloorBuilder = require(script.Parent.FloorBuilder)
local FloorLayout = require(script.Parent.FloorLayout)
local TrapService = require(script.Parent.TrapService)

local ORIGIN = Vector3.new(2000, 0, 0) -- far from the test room
local CHECK_INTERVAL = 0.25
local RESET_AFTER_EMPTY = 4 -- seconds a locked room may stand empty (everyone died) before it resets
local ELITE_CHANCE = 0.4
local TRAP_CHANCE = 0.45
local ARROW_TRAP_CHANCE = 0.3
local TRAP_DAMAGE = 14

local LOOT = {
	Bronze = { Gold = { 20, 40 }, WeaponChance = 0.25, Rarities = { { "Rare", 1 } } },
	Silver = { Gold = { 50, 90 }, WeaponChance = 1, Rarities = { { "Rare", 0.6 }, { "Epic", 0.4 } } },
	Gold = { Gold = { 120, 200 }, WeaponChance = 1, Rarities = { { "Epic", 0.7 }, { "Legendary", 0.3 } } },
}

type Keys = { Bronze: number, Silver: number, Gold: number }

type CombatRoom = {
	Built: FloorBuilder.BuiltRoom,
	Cleared: boolean,
	Active: boolean,
	Spawning: boolean,
	Enemies: { [EnemyService.Enemy]: boolean },
	EmptySince: number?,
	HasElite: boolean,
}

local FloorService = {}

local currentFloor = 0
local floorModel: Model? = nil
local entrance: Vector3 = ORIGIN
local combatRooms: { CombatRoom } = {}
local keys: { [Player]: Keys } = {}
local changingFloor = false
local dungeonFolder: Folder

local runRemote = Remotes.Event("RunUpdated")
local floorStartedRemote = Remotes.Event("FloorStarted")
local notifyRemote = Remotes.Event("Notify")
local damageNumberRemote = Remotes.Event("DamageNumber")

local function keysOf(player: Player): Keys
	local k = keys[player]
	if not k then
		k = { Bronze = 0, Silver = 0, Gold = 0 }
		keys[player] = k
	end
	return k
end

local function pushRun(player: Player)
	runRemote:FireClient(player, {
		Floor = currentFloor,
		Chapter = Floors.ChapterName(currentFloor),
		Keys = keysOf(player),
	})
end

local function giveKey(player: Player, tier: string, position: Vector3?)
	local k = keysOf(player) :: any
	k[tier] += 1
	pushRun(player)
	if position then
		damageNumberRemote:FireClient(player, position + Vector3.new(0, 4.5, 0), `+1 {tier} Key`, "Reward")
	end
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function isInside(room: FloorBuilder.BuiltRoom, position: Vector3, margin: number): boolean
	local offset = position - room.Center
	local half = room.Size / 2 - margin
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half and offset.Y > -4 and offset.Y < 20
end

-- A random spot on a room's floor, away from the walls, the doorways and the middle (if asked).
local function freeSpot(room: FloorBuilder.BuiltRoom, rng: Random, avoidCenter: number?): Vector3
	local half = room.Size / 2 - 5
	local best = room.Center
	for _ = 1, 30 do
		local spot = room.Center + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		local ok = (spot - room.Center).Magnitude >= (avoidCenter or 0)
		for _, doorway in room.Doorways do
			if (spot - doorway).Magnitude < 8 then
				ok = false
			end
		end
		if ok then
			return spot
		end
		best = spot
	end
	return best
end

local function setGates(room: CombatRoom, closed: boolean)
	for _, gate in room.Built.Gates do
		TweenService:Create(gate.Part, TweenInfo.new(if closed then 0.6 else 1.2, Enum.EasingStyle.Quad), {
			CFrame = if closed then gate.Closed else gate.Open,
		}):Play()
	end
end

local function prompt(parent: BasePart, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

------------------------------------------------------------------------------------------------
-- Combat rooms

local function clearRoom(room: CombatRoom)
	room.Active = false
	room.Cleared = true
	setGates(room, false)
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root and isInside(room.Built, root.Position, 0) then
			notifyRemote:FireClient(player, "Room cleared. The gates rise.")
		end
	end
end

local function onEnemyDied(room: CombatRoom, enemy: EnemyService.Enemy)
	room.Enemies[enemy] = nil
	if enemy.Elite then
		for player in enemy.Damagers do
			if player.Parent then
				giveKey(player, "Bronze", enemy.Root.Position)
			end
		end
	end
	if room.Active and not room.Spawning and next(room.Enemies) == nil then
		clearRoom(room)
	end
end

local function activateRoom(room: CombatRoom, floor: number)
	room.Active = true
	room.Spawning = true
	room.EmptySince = nil
	setGates(room, true)

	local rng = Random.new()
	local count = math.min(math.floor(room.Built.Size / 16) + math.floor((floor - 1) / 3), 7)
	local eliteIndex = if room.HasElite then rng:NextInteger(1, count) else 0
	for i = 1, count do
		if not room.Active then
			break
		end
		local spot = freeSpot(room.Built, rng, 6)
		local enemy = EnemyService.Spawn("Skeleton", CFrame.lookAt(spot, room.Center), {
			HealthMultiplier = Floors.EnemyHealthMultiplier(floor),
			DamageMultiplier = Floors.EnemyDamageMultiplier(floor),
			Elite = i == eliteIndex,
			OnDied = function(dead)
				onEnemyDied(room, dead)
			end,
		})
		if enemy then
			room.Enemies[enemy] = true
		end
		task.wait(0.15)
	end
	room.Spawning = false
	if room.Active and next(room.Enemies) == nil then
		clearRoom(room)
	end
end

-- Everyone inside died: the monsters go back to waiting and the gates open, so the room can be tried again.
local function resetRoom(room: CombatRoom)
	room.Active = false
	room.EmptySince = nil
	for enemy in room.Enemies do
		EnemyService.Remove(enemy)
	end
	room.Enemies = {}
	setGates(room, false)
end

local function watchRooms()
	local now = os.clock()
	for _, room in combatRooms do
		if room.Cleared then
			continue
		end
		local anyoneInside = false
		for _, player in Players:GetPlayers() do
			local root = aliveRoot(player)
			if root and isInside(room.Built, root.Position, 1.5) then
				anyoneInside = true
				break
			end
		end
		if not room.Active then
			if anyoneInside then
				task.spawn(activateRoom, room, currentFloor)
			end
		elseif anyoneInside then
			room.EmptySince = nil
		else
			room.EmptySince = room.EmptySince or now
			if now - (room.EmptySince :: number) >= RESET_AFTER_EMPTY then
				resetRoom(room)
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Chests, keys, lever, stairs

local function rollRarity(rng: Random, table_: { { any } }): string
	local roll = rng:NextNumber()
	for _, entry in table_ do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return table_[#table_][1]
end

local function giveLoot(player: Player, tier: string, position: Vector3)
	local loot = (LOOT :: any)[tier]
	local data = DataService.GetData(player)
	if not loot or not data then
		return
	end
	local rng = Random.new()
	local gold = math.floor(rng:NextInteger(loot.Gold[1], loot.Gold[2]) * (1 + 0.15 * (currentFloor - 1)))
	ProgressService.AddGold(player, gold)
	local text = `+{gold} Gold`
	if rng:NextNumber() < loot.WeaponChance then
		local itemName = Items.StarterWeapons[rng:NextInteger(1, #Items.StarterWeapons)]
		local rarity = rollRarity(rng, loot.Rarities)
		InventoryService.AddItem(data, itemName, rarity)
		InventoryService.RefreshTools(player)
		local displayName = Items.Defs[itemName].DisplayName
		text ..= `   {rarity} {displayName}!`
		notifyRemote:FireClient(player, `You found a {rarity} {displayName}!`)
	end
	damageNumberRemote:FireClient(player, position + Vector3.new(0, 3, 0), text, "Reward")
end

local function placeChest(parent: Instance, cframe: CFrame, tier: string)
	local chest = FloorBuilder.Chest(parent, cframe, tier)
	local base = chest:FindFirstChild("Base") :: BasePart
	local lid = chest:FindFirstChild("Lid") :: BasePart
	local openedBy: { [Player]: boolean } = {}
	local lidOpen = false
	local p = prompt(base, "Unlock", `{tier} Chest`, 0.6, 8)
	p.Triggered:Connect(function(player)
		if openedBy[player] then
			notifyRemote:FireClient(player, "You already opened this chest.")
			return
		end
		local k = keysOf(player) :: any
		if k[tier] < 1 then
			notifyRemote:FireClient(player, `You need a {tier} Key.`)
			return
		end
		k[tier] -= 1
		openedBy[player] = true
		pushRun(player)
		if not lidOpen then
			lidOpen = true
			TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back), { CFrame = FloorBuilder.ChestOpenCFrame(lid) }):Play()
		end
		giveLoot(player, tier, base.Position)
	end)
end

local function placeKeyPedestal(parent: Instance, position: Vector3, tier: string)
	local pedestal = FloorBuilder.KeyPedestal(parent, position, tier)
	local takenBy: { [Player]: boolean } = {}
	local p = prompt(pedestal:FindFirstChild("Pedestal") :: BasePart, "Take", `{tier} Key`, 0.4, 8)
	p.Triggered:Connect(function(player)
		if takenBy[player] then
			notifyRemote:FireClient(player, "You already took this key.")
			return
		end
		takenBy[player] = true
		giveKey(player, tier, position)
	end)
end

local function setupLever(room: FloorBuilder.BuiltRoom)
	local lever = room.Lever
	local secretWall = room.SecretWall
	if not lever or not secretWall then
		return
	end
	local handle = lever:FindFirstChild("Handle") :: BasePart
	local p = prompt(lever:FindFirstChild("Plate") :: BasePart, "Pull", "Old Lever", 0.5, 7)
	p.Triggered:Connect(function(player)
		p.Enabled = false
		TweenService:Create(handle, TweenInfo.new(0.3), { CFrame = handle.CFrame * CFrame.Angles(math.rad(-70), 0, 0) }):Play()
		TweenService:Create(secretWall.Part, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = secretWall.Open }):Play()
		notifyRemote:FireAllClients(`{player.DisplayName} pulled a lever. Stone grinds somewhere nearby...`)
	end)
end

local startFloor: (number) -> ()

local function setupStairs(room: FloorBuilder.BuiltRoom)
	local part = room.StairsPart
	if not part then
		return
	end
	local last = currentFloor >= Floors.MaxFloor
	local p = prompt(part, "Descend", if last then "Sealed" else `Floor {currentFloor + 1}`, 1, 10)
	p.Triggered:Connect(function(_player)
		if last then
			notifyRemote:FireAllClients("The way down is sealed... for now.")
			return
		end
		if not changingFloor then
			startFloor(currentFloor + 1)
		end
	end)
end

------------------------------------------------------------------------------------------------
-- Floors

local function sendToEntrance(player: Player)
	local character = player.Character
	if character then
		local offset = Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))
		character:PivotTo(CFrame.new(entrance + offset))
	end
end

startFloor = function(floor: number)
	changingFloor = true
	local rng = Random.new()
	local layout = FloorLayout.Generate(floor, rng)
	local model, rooms, corridors = FloorBuilder.Build(layout, ORIGIN, rng)

	local previous = floorModel
	local previousRooms = combatRooms
	currentFloor = floor
	combatRooms = {}

	for _, room in rooms do
		local plan = room.Plan
		if plan.Type == "Entrance" then
			entrance = room.Center
		elseif plan.Type == "Combat" then
			table.insert(combatRooms, {
				Built = room,
				Cleared = false,
				Active = false,
				Spawning = false,
				Enemies = {},
				EmptySince = nil,
				HasElite = rng:NextNumber() < ELITE_CHANCE,
			})
			setupLever(room)
			if rng:NextNumber() < TRAP_CHANCE then
				local damage = TRAP_DAMAGE * Floors.EnemyDamageMultiplier(floor)
				if rng:NextNumber() < 0.5 then
					for _ = 1, rng:NextInteger(1, 2) do
						TrapService.Spikes(room.Model, CFrame.new(freeSpot(room, rng, 4)), damage)
					end
				else
					TrapService.Flames(room.Model, CFrame.new(freeSpot(room, rng, 4)), damage)
				end
			end
		elseif plan.Type == "Treasure" then
			local count = if floor >= 3 and rng:NextNumber() < 0.35 then 3 else 2
			for i = 1, count do
				local tier = if i == 3 then "Silver" else "Bronze"
				local x = (i - (count + 1) / 2) * 6
				placeChest(room.Model, CFrame.new(room.Center + Vector3.new(x, 0, 0)), tier)
			end
		elseif plan.Type == "Secret" then
			placeKeyPedestal(room.Model, room.Center, "Silver")
			placeChest(room.Model, CFrame.new(room.Center + Vector3.new(0, 0, 6)), "Bronze")
		elseif plan.Type == "Stairs" then
			setupStairs(room)
		end
	end

	if floor >= 2 then
		for _, corridor in corridors do
			if corridor.Length >= 16 and rng:NextNumber() < ARROW_TRAP_CHANCE then
				local side = if rng:NextNumber() < 0.5 then 1 else -1
				local slit = corridor.Frame * CFrame.new(side * (FloorBuilder.DoorWidth / 2 - 0.1), 3, 0)
				local across = -side * corridor.Frame.RightVector
				TrapService.Arrows(model, CFrame.lookAt(slit.Position, slit.Position + across), FloorBuilder.DoorWidth, TRAP_DAMAGE * Floors.EnemyDamageMultiplier(floor))
			end
		end
	end

	model.Name = `Floor{floor}`
	model.Parent = dungeonFolder
	floorModel = model

	if not Config.StartInTestArena then
		for _, player in Players:GetPlayers() do
			sendToEntrance(player)
		end
	end
	-- Enemies left on the old floor go with it.
	for _, room in previousRooms do
		room.Active = false
		for enemy in room.Enemies do
			EnemyService.Remove(enemy)
		end
	end
	if previous then
		previous:Destroy()
	end

	for _, player in Players:GetPlayers() do
		local data = DataService.GetData(player)
		if data and floor > data.DeepestFloor then
			data.DeepestFloor = floor
		end
		pushRun(player)
	end
	floorStartedRemote:FireAllClients(floor, Floors.ChapterName(floor))
	changingFloor = false
end

function FloorService.Start()
	dungeonFolder = Instance.new("Folder")
	dungeonFolder.Name = "Dungeon"
	dungeonFolder.Parent = workspace

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(_character)
			if not Config.StartInTestArena then
				task.defer(sendToEntrance, player)
			end
			task.defer(pushRun, player)
		end)
		if player.Character and not Config.StartInTestArena then
			sendToEntrance(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		keys[player] = nil
	end)
	DataService.OnLoaded(function(player, _data)
		pushRun(player)
		floorStartedRemote:FireClient(player, currentFloor, Floors.ChapterName(currentFloor))
	end)

	startFloor(1)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL and not changingFloor then
			elapsed = 0
			watchRooms()
		end
	end)
end

return FloorService
