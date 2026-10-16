--!strict
-- Runs the dungeon: builds each floor, locks combat rooms until their monsters are dead,
-- hands out keys, opens chests, works the secret lever and takes everyone down the stairs.
--
-- One Depths server is one run (solo, or a party later in stage 6), so the run's state
-- (current floor, keys in hand) lives here in memory. Keys are per player and only last the run.
-- Loot is per player too: everyone with the right key can open every chest once.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Floors = require(ReplicatedStorage.Shared.Floors)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.Parent.Common.DataService)
local InventoryService = require(script.Parent.Parent.Common.InventoryService)
local ProgressService = require(script.Parent.Parent.Common.ProgressService)
local EnemyService = require(script.Parent.EnemyService)
local FloorBuilder = require(script.Parent.FloorBuilder)
local FloorLayout = require(script.Parent.FloorLayout)
local Materials = require(script.Parent.Materials)
local Props = require(script.Parent.Props)
local TrapService = require(script.Parent.TrapService)

local ORIGIN = Vector3.new(2000, 0, 0) -- far from the test room
local CHECK_INTERVAL = 0.25
local RESET_AFTER_EMPTY = 4 -- seconds a locked room may stand empty (everyone died) before it resets
-- An elite in a combat room: more likely deeper down.
local function eliteChance(floor: number): number
	return math.min(0.15 + 0.05 * (floor - 1), 0.7)
end
-- Between fights (not inside a room that's fighting) health slowly comes back; during a fight only potions
-- and the Tome heal. (Roblox's own steady regeneration is turned off in ProgressService.)
local REST_HEAL_PER_SECOND = 0.03
local EVENT_CHANCE = 0.45 -- of a floor (without a boss or the Guardians) having an event
local TRAP_CHANCE = 0.45
local ARROW_TRAP_CHANCE = 0.3
local TRAP_DAMAGE = 14

local LOOT = {
	-- Mostly gold, potions and the floor's monster materials; a weapon only now and then (2026-10-16).
	Bronze = { Gold = { 20, 40 }, Potions = { 0, 1 }, Materials = { 1, 3 }, WeaponChance = 0.1, Rarities = { { "Common", 0.6 }, { "Rare", 0.4 } } },
	Silver = { Gold = { 50, 90 }, Potions = { 1, 2 }, Materials = { 2, 4 }, WeaponChance = 0.4, Rarities = { { "Rare", 0.8 }, { "Epic", 0.2 } } },
	Gold = { Gold = { 120, 200 }, Potions = { 2, 3 }, Materials = { 3, 5 }, WeaponChance = 1, Rarities = { { "Epic", 0.85 }, { "Legendary", 0.15 } } },
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
	KeyBearer: boolean?, -- this room's elite carries the Stairs Key
	EventKind: string?,
	Ambush: boolean?, -- this floor's event: when cleared, a second wave climbs out of the floor
	RewardChest: string?, -- a chest of this tier appears in the middle once the room is cleared (events)
	Guardians: boolean?, -- the Guardians' hall: waves of monsters, then a Skeleton Captain
	Wave: number?,
	Boss: string?, -- a boss's lair: just the boss, and its reward when it falls
	IntroShown: boolean?,
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
local floorPickerRemote = Remotes.Event("FloorPicker")
local notifyRemote = Remotes.Event("Notify")
local damageNumberRemote = Remotes.Event("DamageNumber")
local effectRemote = Remotes.Event("Effect")
local bossIntroRemote = Remotes.Event("BossIntro")
local BOSS_INTRO_SECONDS = 11

local function keysOf(player: Player): Keys
	local k = keys[player]
	if not k then
		k = { Bronze = 0, Silver = 0, Gold = 0 }
		keys[player] = k
	end
	return k
end

-- From floor 2 the stairs down are sealed until someone finds this floor's Stairs Key: an elite in one of
-- the combat rooms carries it, or it waits on a pedestal in the treasure room. One key opens the way for everyone.
-- (Boss floors need none: the lair stands before the stairs.)
local stairsKey: { Needed: boolean, Found: boolean, Where: string } = { Needed = false, Found = false, Where = "" }
local floorEvent: string? = nil -- this floor's event, told to players when they arrive

local function pushRun(player: Player)
	runRemote:FireClient(player, {
		Floor = currentFloor,
		Chapter = Floors.ChapterName(currentFloor),
		Keys = keysOf(player),
		StairsKey = if stairsKey.Needed then (if stairsKey.Found then "Found" else stairsKey.Where) else nil,
	})
end

local function findStairsKey(player: Player, position: Vector3?)
	if stairsKey.Found then
		return
	end
	stairsKey.Found = true
	notifyRemote:FireAllClients(`{player.DisplayName} found the Stairs Key! The way down is open.`)
	if position then
		damageNumberRemote:FireAllClients(position + Vector3.new(0, 4, 0), "Stairs Key!", "Reward")
	end
	for _, other in Players:GetPlayers() do
		pushRun(other)
	end
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

local bossDefeated: (CombatRoom, EnemyService.Enemy) -> ()
local roomEmptied: (CombatRoom) -> ()
local guardiansDefeated: (CombatRoom) -> ()

local function onEnemyDied(room: CombatRoom, enemy: EnemyService.Enemy)
	-- Slimes split: the little ones join the fight before the room checks whether it is clear.
	local split = enemy.Def.SplitInto
	if split and room.Active then
		for i = 1, split.Count do
			local angle = (i / split.Count) * math.pi * 2
			local at = enemy.Root.Position + Vector3.new(math.cos(angle) * 2, 0, math.sin(angle) * 2)
			local ok, child = pcall(EnemyService.Spawn, split.Name, CFrame.new(at - Vector3.new(0, 2, 0)), {
				HealthMultiplier = Floors.EnemyHealthMultiplier(currentFloor),
				DamageMultiplier = Floors.EnemyDamageMultiplier(currentFloor),
				OnDied = function(dead)
					onEnemyDied(room, dead)
				end,
			})
			if ok and child then
				room.Enemies[child] = true
			end
		end
	end
	room.Enemies[enemy] = nil
	if room.Boss and enemy.Def.Boss then
		bossDefeated(room, enemy)
	end
	if enemy.Elite then
		for player in enemy.Damagers do
			if player.Parent then
				giveKey(player, "Bronze", enemy.Root.Position)
			end
		end
		if room.KeyBearer then
			room.KeyBearer = false
			local finder = next(enemy.Damagers)
			if finder then
				findStairsKey(finder, enemy.Root.Position)
			end
		end
	end
	if room.Active and not room.Spawning and next(room.Enemies) == nil then
		roomEmptied(room)
	end
end

-- The ring of runes on a lair's floor glows green while its boss fights, and goes dark when it falls.
local function lightRunes(built: FloorBuilder.BuiltRoom, on: boolean)
	local i = 0
	for _, rune in built.Model:GetChildren() do
		if rune.Name == "LairRune" and rune:IsA("BasePart") then
			i += 1
			if on then
				rune.Material = Enum.Material.Neon
			end
			-- they catch one after another round the ring
			TweenService:Create(rune, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, if on then (i % 40) * 0.04 else 0), {
				Color = if on then Color3.fromRGB(80, 230, 130) else Color3.fromRGB(34, 38, 36),
			}):Play()
			if not on then
				task.delay(0.5, function()
					rune.Material = Enum.Material.Slate
				end)
			end
		end
	end
end

-- The Guardians' hall: three waves, each rising when the last one falls; the third led by the Captain.
local GUARDIAN_WAVES = {
	{ { "Skeleton", 5 } },
	{ { "SkeletonArcher", 3 }, { "Skeleton", 3 } },
	{ { "Captain", 1 }, { "Skeleton", 2 }, { "SkeletonArcher", 2 } },
}

local function spawnWave(room: CombatRoom, floor: number, wave: number)
	room.Spawning = true
	room.Wave = wave
	local rng = Random.new()
	local extra = math.max(#Players:GetPlayers(), 1) - 1
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root and isInside(room.Built, root.Position, -4) then
			notifyRemote:FireClient(player, if wave == #GUARDIAN_WAVES then "The Skeleton Captain rises!" else `Wave {wave} of {#GUARDIAN_WAVES}`)
		end
	end
	for _, group in GUARDIAN_WAVES[wave] do
		local name, count = group[1], group[2]
		if name ~= "Captain" then
			count += extra
		end
		for _ = 1, count do
			if not room.Active then
				room.Spawning = false
				return
			end
			local spot = freeSpot(room.Built, rng, 6)
			effectRemote:FireAllClients("Rise", spot)
			local captain = name == "Captain"
			local ok, enemy = pcall(EnemyService.Spawn, if captain then "Skeleton" else name, CFrame.lookAt(spot, room.Built.Center), {
				HealthMultiplier = Floors.EnemyHealthMultiplier(floor) * (if captain then 3 * (1 + 0.6 * extra) else 1),
				DamageMultiplier = Floors.EnemyDamageMultiplier(floor),
				Elite = captain,
				Title = if captain then "Skeleton Captain" else nil,
				ExtraScale = if captain then 1.5 else nil,
				OnDied = function(dead)
					onEnemyDied(room, dead)
				end,
			})
			if ok and enemy then
				room.Enemies[enemy] = true
			else
				warn(`[FloorService] Spawning a guardian failed: {enemy}`)
			end
			task.wait(0.25)
		end
	end
	room.Spawning = false
	if room.Active and next(room.Enemies) == nil then
		roomEmptied(room)
	end
end

-- More of the floor's monsters climbing out of the ground, all over the room.
local function riseEnemies(room: CombatRoom, floor: number, count: number)
	local rng = Random.new()
	for _ = 1, count do
		if not room.Active then
			break
		end
		local spot = freeSpot(room.Built, rng, 4)
		effectRemote:FireAllClients("Rise", spot)
		local ok, enemy = pcall(EnemyService.Spawn, Floors.PickEnemy(floor, rng), CFrame.lookAt(spot, room.Built.Center), {
			HealthMultiplier = Floors.EnemyHealthMultiplier(floor),
			DamageMultiplier = Floors.EnemyDamageMultiplier(floor),
			OnDied = function(dead)
				onEnemyDied(room, dead)
			end,
		})
		if ok and enemy then
			room.Enemies[enemy] = true
		end
		task.wait(0.3)
	end
end

local placeChestLater: (CombatRoom, string) -> ()

roomEmptied = function(room: CombatRoom)
	if room.Ambush then
		-- The floor's event: just as the gates should rise, more of them crawl out.
		room.Ambush = false
		room.RewardChest = "Bronze"
		room.Spawning = true
		for _, player in Players:GetPlayers() do
			local root = aliveRoot(player)
			if root and isInside(room.Built, root.Position, -4) then
				notifyRemote:FireClient(player, "Ambush! More of them crawl out of the ground!")
			end
		end
		task.delay(1.5, function()
			local extra = math.max(#Players:GetPlayers(), 1) - 1
			riseEnemies(room, currentFloor, 3 + math.floor(currentFloor / 3) + extra)
			room.Spawning = false
			if room.Active and next(room.Enemies) == nil then
				roomEmptied(room)
			end
		end)
		return
	end
	if room.RewardChest then
		placeChestLater(room, room.RewardChest)
		room.RewardChest = nil
	end
	if room.Guardians and (room.Wave or 0) < #GUARDIAN_WAVES then
		local nextWave = (room.Wave or 0) + 1
		room.Spawning = true -- nothing else may clear the hall while the next wave is on its way
		task.delay(2.5, function()
			if room.Active then
				spawnWave(room, currentFloor, nextWave)
			else
				room.Spawning = false
			end
		end)
		return
	end
	clearRoom(room)
	if room.Guardians then
		guardiansDefeated(room)
	end
end

local function activateRoom(room: CombatRoom, floor: number)
	room.Active = true
	room.Spawning = true
	room.EmptySince = nil
	setGates(room, true)

	local rng = Random.new()
	if room.Guardians then
		spawnWave(room, floor, 1)
		return
	end
	if room.Boss then
		-- The boss waits at the door of its tomb on the far side of the lair (or just on the far side), facing
		-- the way in; it grows tougher for each extra player.
		local party = math.max(#Players:GetPlayers(), 1)
		local doorway = room.Built.Doorways[1] or room.Built.Center
		local away = room.Built.Center - doorway
		away = if away.Magnitude > 0.1 then Vector3.new(away.X, 0, away.Z).Unit else Vector3.new(0, 0, -1)
		local stepOut = room.Built.Model:GetAttribute("BossSpot") :: Vector3?
		local spot = (room.Built.Model:GetAttribute("BossDoor") :: Vector3?) or room.Built.Center + away * (room.Built.Size / 4)
		local ok, boss = pcall(EnemyService.Spawn, room.Boss, CFrame.lookAt(spot, Vector3.new(room.Built.Center.X, spot.Y, room.Built.Center.Z)), {
			HealthMultiplier = 1 + 0.6 * (party - 1),
			DamageMultiplier = 1,
			MinionMultiplier = Floors.EnemyHealthMultiplier(floor),
			OnDied = function(dead)
				onEnemyDied(room, dead)
			end,
		})
		if not ok then
			warn(`[FloorService] Spawning the boss failed: {boss}`)
		elseif boss then
			room.Enemies[boss] = true
			local def = boss.Def.Boss :: any
			if not room.IntroShown then
				-- Once a run: the gates slam, the camera turns to the boss and it speaks.
				room.IntroShown = true
				bossIntroRemote:FireAllClients(boss.Model, def.Title, def.Intro.Subtitle, def.Intro.Lines, BOSS_INTRO_SECONDS)
				EnemyService.PlayIntro(boss, BOSS_INTRO_SECONDS, stepOut)
			else
				notifyRemote:FireAllClients(`{def.Title} rises again!`)
			end
			lightRunes(room.Built, true)
		end
		room.Spawning = false
		return
	end
	-- Floor 1: two or three (by room size), then one more every second floor.
	local count = math.min(math.max(math.floor(room.Built.Size / 16), 2) + math.floor((floor - 1) / 2), 8)
	local eliteIndex = if room.HasElite then rng:NextInteger(1, count) else 0
	for i = 1, count do
		if not room.Active then
			break
		end
		local spot = freeSpot(room.Built, rng, 6)
		local name = Floors.PickEnemy(floor, rng)
		local pack = Enemies[name].Pack
		for member = 1, if pack then rng:NextInteger(pack[1], pack[2]) else 1 do
			local at = spot + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
			-- A spawn that fails must not leave the room waiting forever.
			local ok, enemy = pcall(EnemyService.Spawn, name, CFrame.lookAt(at, room.Built.Center), {
				HealthMultiplier = Floors.EnemyHealthMultiplier(floor),
				DamageMultiplier = Floors.EnemyDamageMultiplier(floor),
				Elite = i == eliteIndex and member == 1,
				OnDied = function(dead)
					onEnemyDied(room, dead)
				end,
			})
			if not ok then
				warn(`[FloorService] Spawning an enemy failed: {enemy}`)
			elseif enemy then
				room.Enemies[enemy] = true
			end
		end
		task.wait(0.15)
	end
	room.Spawning = false
	if room.Active and next(room.Enemies) == nil then
		roomEmptied(room)
	end
end

-- Everyone inside died: the monsters go back to waiting and the gates open, so the room can be tried again.
local function resetRoom(room: CombatRoom)
	room.Active = false
	room.EmptySince = nil
	if room.Guardians then
		room.Wave = 0
	end
	if room.RewardChest == "Bronze" and room.EventKind == "Ambush" then
		room.Ambush = true
		room.RewardChest = nil
	end
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
		-- A lair only locks once a player is well past its gates; after that, a player shoved back into a
		-- gateway still counts as inside.
		local margin = if not (room.Boss or room.Guardians) then 1.5 elseif room.Active then -4 else 6
		local anyoneInside = false
		for _, player in Players:GetPlayers() do
			local root = aliveRoot(player)
			if root and isInside(room.Built, root.Position, margin) then
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
			if not room.Spawning then
				-- Safety net: a monster that slipped out of the room (into a wall, under the floor) is put
				-- back in the middle where it can be fought; one that vanished without dying is forgotten.
				for enemy in room.Enemies do
					if enemy.Dead or not enemy.Model.Parent then
						room.Enemies[enemy] = nil
					elseif not isInside(room.Built, enemy.Root.Position, 0.5) then
						warn(`[FloorService] An enemy left room {room.Built.Plan.Key}; bringing it back`)
						enemy.Root.CFrame = CFrame.new(freeSpot(room.Built, Random.new(), 4) + Vector3.new(0, enemy.Humanoid.HipHeight + 2, 0))
					end
				end
				if next(room.Enemies) == nil then
					roomEmptied(room)
				end
			end
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
	local potions = rng:NextInteger(loot.Potions[1], loot.Potions[2])
	if potions > 0 then
		local got = InventoryService.GiveItem(player, "HealthPotion", "Common", potions)
		if got > 0 then
			text ..= `   +{got} Health Potion`
		end
	end
	-- A handful of what this floor's monsters leave behind.
	local pool = {}
	for _, entry in Floors.EnemyMix(currentFloor) do
		local def = Enemies[entry.Name]
		for _, drop in (def and def.Drops) or {} do
			if not table.find(pool, drop.Item) then
				table.insert(pool, drop.Item)
			end
		end
	end
	if #pool > 0 then
		local material = pool[rng:NextInteger(1, #pool)]
		local got = InventoryService.GiveItem(player, material, "Common", rng:NextInteger(loot.Materials[1], loot.Materials[2]))
		if got > 0 then
			text ..= `   +{got} {Items.Defs[material].DisplayName}`
		end
	end
	if rng:NextNumber() < loot.WeaponChance then
		local itemName = Items.StarterWeapons[rng:NextInteger(1, #Items.StarterWeapons)]
		local rarity = rollRarity(rng, loot.Rarities)
		InventoryService.GiveItem(player, itemName, rarity)
		text ..= `   {rarity} {Items.NameFor(itemName, rarity)}!`
	end
	damageNumberRemote:FireClient(player, position + Vector3.new(0, 3, 0), text, "Reward")
end

local function placeChest(parent: Instance, cframe: CFrame, tier: string)
	local chest = FloorBuilder.Chest(parent, cframe, tier)
	local base = chest:FindFirstChild("Base", true) :: BasePart
	local lid = chest:FindFirstChild("Lid", true) :: BasePart?
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
			if lid then
				TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back), { CFrame = FloorBuilder.ChestOpenCFrame(lid) }):Play()
			else
				-- A closed chest with no lid: it jolts and flares with light in its key's color.
				local rest = base.CFrame
				TweenService:Create(base, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), { CFrame = rest * CFrame.new(0, 0.35, 0) * CFrame.Angles(math.rad(4), 0, 0) }):Play()
				local glow = base:FindFirstChild("TierGlow") :: PointLight?
				if glow then
					glow.Brightness = 6
					glow.Range = 16
					TweenService:Create(glow, TweenInfo.new(1.6), { Brightness = 0.6, Range = 7 }):Play()
				end
			end
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

-- A boss lair is lit brighter than other rooms, so the fight and its warnings can be seen:
-- a fire bowl in each corner and a cold light high above the middle.
local function lightLair(room: FloorBuilder.BuiltRoom)
	local half = room.Size / 2 - 7
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local spot = room.Center + Vector3.new(sx * half, 0, sz * half)
			local stand = Instance.new("Part")
			stand.Name = "FireBowlStand"
			stand.Anchored = true
			stand.Size = Vector3.new(1.2, 3.2, 1.2)
			stand.CFrame = CFrame.new(spot + Vector3.new(0, 1.6, 0))
			stand.Color = Color3.fromRGB(45, 42, 40)
			stand.Material = Enum.Material.Metal
			stand.Parent = room.Model
			local bowl = Instance.new("Part")
			bowl.Name = "FireBowl"
			bowl.Anchored = true
			bowl.Shape = Enum.PartType.Cylinder
			bowl.Size = Vector3.new(0.8, 3, 3)
			bowl.CFrame = CFrame.new(spot + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
			bowl.Color = Color3.fromRGB(55, 50, 45)
			bowl.Material = Enum.Material.Metal
			bowl.Parent = room.Model
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Heat = 9
			fire.Color = Color3.fromRGB(255, 140, 50)
			fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
			fire.Parent = bowl
			CollectionService:AddTag(fire, "LairFire")
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 160, 90)
			light.Range = 34
			light.Brightness = 1.6
			light.Shadows = true
			light.Parent = bowl
		end
	end
	local above = Instance.new("Part")
	above.Name = "LairLight"
	above.Anchored = true
	above.CanCollide = false
	above.CanQuery = false
	above.Transparency = 1
	above.Size = Vector3.new(1, 1, 1)
	above.CFrame = CFrame.new(room.Center + Vector3.new(0, 16, 0))
	above.Parent = room.Model
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(190, 200, 230)
	glow.Range = 45
	glow.Brightness = 0.9
	glow.Parent = above
end

local startFloor: (number) -> ()

-- A boss falls: everyone who fought it gets a Gold Key, a Gold Chest appears where it stood,
-- and the next floor becomes their checkpoint (a new run can start right there).
bossDefeated = function(room: CombatRoom, boss: EnemyService.Enemy)
	local title = (boss.Def.Boss :: any).Title
	local where = boss.Root.Position
	lightRunes(room.Built, false)
	for player in boss.Damagers do
		if player.Parent then
			giveKey(player, "Gold", where)
			local data = DataService.GetData(player)
			if data and currentFloor + 1 > (data.Checkpoint or 0) then
				data.Checkpoint = currentFloor + 1
			end
		end
	end
	notifyRemote:FireAllClients(`{title} has fallen! A Gold Chest waits in the lair.`)
	task.delay(2.5, function()
		if room.Built.Model.Parent then
			placeChest(room.Built.Model, CFrame.new(room.Built.Center), "Gold")
		end
	end)
end

-- The Captain is down: like a boss, everyone in the hall gets a Gold Key, the next floor becomes their
-- checkpoint, and a Gold Chest appears.
placeChestLater = function(room: CombatRoom, tier: string)
	task.delay(1.5, function()
		if room.Built.Model.Parent then
			placeChest(room.Built.Model, CFrame.new(room.Built.Center), tier)
		end
	end)
end

guardiansDefeated = function(room: CombatRoom)
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root and isInside(room.Built, root.Position, -4) then
			giveKey(player, "Gold", root.Position)
			local data = DataService.GetData(player)
			if data and currentFloor + 1 > (data.Checkpoint or 0) then
				data.Checkpoint = currentFloor + 1
			end
		end
	end
	notifyRemote:FireAllClients("The guardians have fallen! A Gold Chest waits in the hall.")
	task.delay(2.5, function()
		if room.Built.Model.Parent then
			placeChest(room.Built.Model, CFrame.new(room.Built.Center), "Gold")
		end
	end)
end

-- On floor 1, a gate stone in the entrance hall lets a player who has beaten a boss start from its checkpoint.
-- The deepest floor a player may start a run on: any floor they have reached, or the checkpoint past a boss.
local function unlockedFloor(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 1
	end
	return math.clamp(math.max(data.Checkpoint or 0, data.DeepestFloor or 0, 1), 1, Floors.MaxFloor)
end

local checkpointStone: BasePart? = nil

-- The waystone in floor 1's entrance: it opens the floor picker (FloorPicker on the client), so a run can
-- start on any floor already reached, to go back and grow stronger or to go straight down.
local function setupCheckpointStone(room: FloorBuilder.BuiltRoom)
	local stone = FloorBuilder.KeyPedestal(room.Model, room.Center + Vector3.new(0, 0, 9), "Gold")
	stone.Name = "CheckpointStone"
	local base = stone:FindFirstChild("Pedestal") :: BasePart
	checkpointStone = base
	local p = prompt(base, "Choose floor", "Waystone", 0.5, 9)
	p.Enabled = false
	local function refresh()
		local best = 1
		for _, player in Players:GetPlayers() do
			best = math.max(best, unlockedFloor(player))
		end
		p.Enabled = best > 1 and currentFloor == 1
	end
	refresh()
	task.spawn(function()
		while stone.Parent do
			task.wait(2)
			refresh()
		end
	end)
	p.Triggered:Connect(function(player)
		local marks = {}
		for floor in Floors.Bosses do
			marks[tostring(floor)] = "Boss"
		end
		for floor in Floors.Guardians do
			marks[tostring(floor)] = "Guardians"
		end
		floorPickerRemote:FireClient(player, { Unlocked = unlockedFloor(player), Max = Floors.MaxFloor, Marks = marks })
	end)
end

-- A player picked a floor at the waystone: checked again here (reached it, standing at the stone, on floor 1).
local function onChooseFloor(player: Player, floor: any)
	if type(floor) ~= "number" or floor ~= math.floor(floor) or floor < 1 or floor > unlockedFloor(player) then
		return
	end
	local root = aliveRoot(player)
	local stone = checkpointStone
	if changingFloor or currentFloor ~= 1 or not root or not stone or not stone.Parent or (root.Position - stone.Position).Magnitude > 16 then
		return
	end
	if floor == 1 then
		return
	end
	notifyRemote:FireAllClients(`{player.DisplayName} opens the way to floor {floor}.`)
	startFloor(floor)
end

-- The wandering merchant (a floor event): a hooded figure with a lantern and a crate of potions near the
-- entrance. Sells health potions for gold; selling to him isn't possible (only the shops in Emberhold buy).
local function setupMerchant(room: FloorBuilder.BuiltRoom, floor: number)
	local price = 20 + 3 * floor
	local model = Instance.new("Model")
	model.Name = "WanderingMerchant"
	local spot = room.Center + Vector3.new(room.Size / 2 - 7, 0, room.Size / 2 - 9)
	local face = CFrame.lookAt(spot, Vector3.new(room.Center.X, spot.Y, room.Center.Z))
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local ROBE = Color3.fromRGB(58, 44, 40)
	-- The Tripo merchant (DungeonProps.Merchant) when there is one, a figure of parts otherwise.
	local figure = Props.Place("Merchant", model, face)
	local body: BasePart
	if figure then
		body = figure:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 180, 100)
		glow.Range = 16
		glow.Brightness = 1.4
		glow.Shadows = true
		glow.Parent = body
	else
		-- the robe, wider at the hem, the hood and the dark inside of it with two dim eyes
		body = piece("Robe", Vector3.new(2.6, 4.4, 2), face * CFrame.new(0, 2.2, 0), ROBE, Enum.Material.Fabric)
		piece("Hem", Vector3.new(3.2, 1.2, 2.5), face * CFrame.new(0, 0.6, 0), ROBE, Enum.Material.Fabric)
		piece("Shoulders", Vector3.new(3, 0.8, 2.1), face * CFrame.new(0, 4.3, 0), ROBE, Enum.Material.Fabric)
		piece("Hood", Vector3.new(2, 2.2, 2), face * CFrame.new(0, 5.4, 0.1), ROBE, Enum.Material.Fabric, Enum.PartType.Ball)
		piece("HoodShadow", Vector3.new(1.3, 1.4, 0.4), face * CFrame.new(0, 5.3, -0.85), Color3.fromRGB(8, 6, 6), Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			local eye = piece("Eye", Vector3.new(0.16, 0.1, 0.06), face * CFrame.new(side * 0.25, 5.4, -1.06), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
			eye.CastShadow = false
		end
		piece("Belt", Vector3.new(2.7, 0.3, 2.1), face * CFrame.new(0, 2.6, 0), Color3.fromRGB(90, 62, 36), Enum.Material.Leather)
		-- a staff with a lantern hanging from it
		local staff = piece("Staff", Vector3.new(0.25, 7, 0.25), face * CFrame.new(1.8, 3.5, -0.4), Color3.fromRGB(70, 48, 30), Enum.Material.Wood)
		local lantern = piece("Lantern", Vector3.new(0.6, 0.8, 0.6), staff.CFrame * CFrame.new(0, 3.1, -0.45), Color3.fromRGB(255, 190, 100), Enum.Material.Neon)
		lantern.Transparency = 0.2
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 180, 100)
		glow.Range = 16
		glow.Brightness = 1.6
		glow.Shadows = true
		glow.Parent = lantern
	end
	-- the crate of potions in front of him
	local crate = piece("Crate", Vector3.new(3, 1.8, 2), face * CFrame.new(0, 0.9, -2.6), Color3.fromRGB(96, 68, 42), Enum.Material.WoodPlanks)
	-- the potions for sale on top: the real potion model (ReplicatedStorage.ItemModels) when there is one
	local items = game:GetService("ReplicatedStorage"):FindFirstChild("ItemModels")
	local potionModel = items and items:FindFirstChild("HealthPotion")
	for i = 0, 3 do
		local at = crate.CFrame * CFrame.new(-1.05 + i * 0.7, 0.9, (i % 2) * 0.4 - 0.2)
		if potionModel and potionModel:IsA("Model") then
			local bottle = potionModel:Clone()
			bottle:ScaleTo(bottle:GetScale() * 0.6)
			bottle:PivotTo(at * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, i * 1.3, 0))
			for _, d in bottle:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			bottle.Parent = model
		else
			local bottle = piece("Potion", Vector3.new(0.55, 0.55, 0.55), at * CFrame.new(0, 0.28, 0), Color3.fromRGB(200, 30, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			bottle.CastShadow = false
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= body and p ~= crate then
			p.CanCollide = false
		end
	end
	model.Parent = room.Model

	local buy = prompt(crate, "Buy", `Health Potion: {price} Gold`, 0.3, 9)
	buy.Triggered:Connect(function(player)
		local data = DataService.GetData(player)
		if not data then
			return
		end
		if data.Gold < price then
			notifyRemote:FireClient(player, `The merchant shakes his head. A potion costs {price} gold.`)
			return
		end
		local got = InventoryService.GiveItem(player, "HealthPotion", "Common", 1)
		if got > 0 then
			ProgressService.AddGold(player, -price)
		end
	end)
end

local function setupStairs(room: FloorBuilder.BuiltRoom)
	local part = room.StairsPart
	if not part then
		return
	end
	local last = currentFloor >= Floors.MaxFloor
	local p = prompt(part, "Descend", if last then "Sealed" else `Floor {currentFloor + 1}`, 1, 10)
	p.Triggered:Connect(function(player)
		if last then
			notifyRemote:FireAllClients("The way down is sealed... for now.")
			return
		end
		if stairsKey.Needed and not stairsKey.Found then
			notifyRemote:FireClient(player, if stairsKey.Where == "Elite"
				then "The stairs are sealed. An elite on this floor carries the Stairs Key."
				else "The stairs are sealed. The Stairs Key lies in this floor's treasure room.")
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
	local hasTreasure = false
	for _, room in rooms do
		if room.Plan.Type == "Treasure" then
			hasTreasure = true
		end
	end
	floorEvent = nil
	stairsKey = {
		Needed = floor >= 2 and not Floors.Bosses[floor] and not Floors.Guardians[floor],
		Found = false,
		Where = if hasTreasure and rng:NextNumber() < 0.5 then "Treasure" else "Elite",
	}

	for _, room in rooms do
		local plan = room.Plan
		if plan.Type == "Entrance" then
			entrance = room.Center
			if floor == 1 then
				setupCheckpointStone(room)
			end
		elseif plan.Type == "Boss" then
			lightLair(room)
			table.insert(combatRooms, {
				Built = room,
				Cleared = false,
				Active = false,
				Spawning = false,
				Enemies = {},
				EmptySince = nil,
				HasElite = false,
				Boss = Floors.Bosses[floor],
			})
		elseif plan.Type == "Guardians" then
			lightLair(room)
			table.insert(combatRooms, {
				Built = room,
				Cleared = false,
				Active = false,
				Spawning = false,
				Enemies = {},
				EmptySince = nil,
				HasElite = false,
				Guardians = true,
				Wave = 0,
			})
		elseif plan.Type == "Combat" then
			table.insert(combatRooms, {
				Built = room,
				Cleared = false,
				Active = false,
				Spawning = false,
				Enemies = {},
				EmptySince = nil,
				HasElite = rng:NextNumber() < eliteChance(floor),
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
			if stairsKey.Needed and stairsKey.Where == "Treasure" then
				local pedestal = FloorBuilder.KeyPedestal(room.Model, room.Center + Vector3.new(0, 0, -7), "Silver")
				pedestal.Name = "StairsKeyPedestal"
				for _, light in pedestal:GetDescendants() do
					if light:IsA("PointLight") then
						light.Color = Color3.fromRGB(120, 255, 170)
						light.Brightness = 2.5
					end
				end
				local take = prompt(pedestal:FindFirstChild("Pedestal") :: BasePart, "Take", "Stairs Key", 0.4, 8)
				take.Triggered:Connect(function(player)
					findStairsKey(player, room.Center)
					take.Enabled = false
				end)
			end
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

	-- From floor 2, about half the floors have an event: an ambush, a trapped room, or the wandering merchant
	-- (always the merchant before a boss or the Guardians, to stock up). The other floors are just floors.
	local lairAhead = Floors.Bosses[floor] ~= nil or Floors.Guardians[floor] == true
	if floor >= 2 and (lairAhead or rng:NextNumber() < EVENT_CHANCE) then
		local lairFloor = Floors.Bosses[floor] ~= nil or Floors.Guardians[floor] == true
		local kinds = { "Ambush", "Traps", "Merchant" }
		local kind = if lairFloor then "Merchant" else kinds[rng:NextInteger(1, #kinds)]
		local later = {}
		for i, room in combatRooms do
			if i > 1 and not room.Boss and not room.Guardians then
				table.insert(later, room)
			end
		end
		if kind ~= "Merchant" and #later == 0 then
			kind = "Merchant"
		end
		if kind == "Merchant" then
			for _, room in rooms do
				if room.Plan.Type == "Entrance" then
					setupMerchant(room, floor)
				end
			end
			floorEvent = "A wandering merchant has set up near the entrance."
		elseif kind == "Ambush" then
			local room = later[rng:NextInteger(1, #later)]
			room.Ambush = true
			room.EventKind = "Ambush"
			floorEvent = "Something stirs beneath this floor..."
		else
			local room = later[rng:NextInteger(1, #later)]
			room.EventKind = "Traps"
			room.RewardChest = "Silver"
			local damage = TRAP_DAMAGE * Floors.EnemyDamageMultiplier(floor)
			for _ = 1, 3 do
				TrapService.Spikes(room.Built.Model, CFrame.new(freeSpot(room.Built, rng, 4)), damage)
			end
			for _ = 1, 2 do
				TrapService.Flames(room.Built.Model, CFrame.new(freeSpot(room.Built, rng, 4)), damage)
			end
			floorEvent = "One of this floor's rooms is full of traps, and a Silver Chest waits past them."
		end
	end

	if stairsKey.Needed and stairsKey.Where == "Elite" then
		local candidates = {}
		for i, room in combatRooms do
			if not room.Boss and i > 1 then
				table.insert(candidates, room)
			end
		end
		if #candidates == 0 then
			candidates = combatRooms
		end
		local bearer = candidates[rng:NextInteger(1, #candidates)]
		if bearer then
			bearer.HasElite = true
			bearer.KeyBearer = true
		else
			stairsKey.Needed = false
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

	Materials.Apply(model)
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
	if floorEvent then
		local told = floorEvent
		task.delay(4, function()
			if currentFloor == floor then
				notifyRemote:FireAllClients(told)
			end
		end)
	end
	changingFloor = false
end

function FloorService.Start()
	dungeonFolder = Instance.new("Folder")
	dungeonFolder.Name = "Dungeon"
	dungeonFolder.Parent = workspace

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			if Config.TestMode and Config.TestNoDamage then
				local shield = Instance.new("ForceField")
				shield.Visible = false
				shield.Parent = character
			end
			if not Config.StartInTestArena then
				task.defer(sendToEntrance, player)
			end
			task.defer(pushRun, player)
		end)
		if player.Character and not Config.StartInTestArena then
			sendToEntrance(player)
		end
		if player.Character and Config.TestMode and Config.TestNoDamage then
			local shield = Instance.new("ForceField")
			shield.Visible = false
			shield.Parent = player.Character
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

	Remotes.Event("ChooseFloor").OnServerEvent:Connect(onChooseFloor)
	startFloor(if Config.TestMode and Config.TestStartFloor then Config.TestStartFloor else 1)

	local elapsed = 0
	local restElapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		restElapsed += dt
		if elapsed >= CHECK_INTERVAL and not changingFloor then
			elapsed = 0
			watchRooms()
		end
		if restElapsed >= 1 then
			restElapsed = 0
			for _, player in Players:GetPlayers() do
				local root = aliveRoot(player)
				local humanoid = root and (player.Character :: Model):FindFirstChildOfClass("Humanoid")
				if not root or not humanoid or humanoid.Health >= humanoid.MaxHealth then
					continue
				end
				local fighting = false
				for _, room in combatRooms do
					if room.Active and isInside(room.Built, root.Position, -4) then
						fighting = true
						break
					end
				end
				if not fighting then
					humanoid.Health = math.min(humanoid.Health + humanoid.MaxHealth * REST_HEAL_PER_SECOND, humanoid.MaxHealth)
				end
			end
		end
	end)
end

return FloorService
