--!strict
-- Player attacks. The client only says "I attacked with this weapon, in this direction".
-- The server checks the weapon is really in the player's hand and off cooldown, then finds
-- the hits itself from where everything really is.
-- What can be hit comes from the place: the Depths' monsters (EnemyService), Emberhold's training dummies
-- (TrainingService). Each target has a Root part; Damage(target, amount, player, kind) lands a blow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Leveling = require(ReplicatedStorage.Shared.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local BlightService = require(script.Parent.BlightService)

export type Target = { Root: BasePart }
export type Targets = {
	GetAlive: () -> { any },
	Damage: (any, number, Player, string) -> (),
}

local COOLDOWN_TOLERANCE = 0.85 -- accept attacks slightly early, for network jitter
local ENEMY_RADIUS = 1.5 -- an enemy's body counts as hit this far from its center

local CombatService = {}

local attackRemote = Remotes.Event("Attack")
local effectRemote = Remotes.Event("Effect")
local damageNumberRemote = Remotes.Event("DamageNumber")
local targets: Targets
local lastAttack: { [Player]: number } = {}
local comboCount: { [Player]: number } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function playSwing(tool: Tool, anim: string?)
	if not anim then
		return
	end
	-- Roblox's default character animations play a slash or lunge when this value appears.
	local value = Instance.new("StringValue")
	value.Name = "toolanim"
	value.Value = anim
	value.Parent = tool
	task.delay(0.5, function()
		value:Destroy()
	end)
end

-- Where a shot leaves the weapon: its "Muzzle" attachment (the staff's crystal, the book) if it has one
-- and it's where the player is, otherwise the usual spot in front of the chest.
local function muzzleOf(tool: Tool, fallback: Vector3): Vector3
	local handle = tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("Attachment") and (muzzle.WorldPosition - fallback).Magnitude < 8 then
		return muzzle.WorldPosition
	end
	return fallback
end

local function onAttack(player: Player, itemId: unknown, direction: unknown, aimPoint: unknown)
	if type(itemId) ~= "string" or typeof(direction) ~= "Vector3" then
		return
	end
	if aimPoint ~= nil and typeof(aimPoint) ~= "Vector3" then
		return
	end
	local aim = flat(direction :: Vector3)
	if aim.Magnitude < 0.01 or aim.Magnitude ~= aim.Magnitude then
		return
	end
	aim = aim.Unit

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not humanoid or humanoid.Health <= 0 or not root or not tool or tool:GetAttribute("ItemId") ~= itemId then
		return
	end
	local item, def = InventoryService.GetItem(player, itemId)
	local weapon = def and def.WeaponType and Weapons[def.WeaponType]
	local data = DataService.GetData(player)
	if not item or not weapon or not data then
		return
	end

	local now = os.clock()
	local last = lastAttack[player]
	if last and now - last < weapon.Cooldown * COOLDOWN_TOLERANCE then
		return
	end
	lastAttack[player] = now

	local damage = Items.WeaponDamage(item.Item, item.Rarity, item.Upgrade) * Leveling.DamageMultiplier(data.Level)
	local spell = Items.Defs[item.Item]
	if spell and (spell.WeaponType == "Staff" or spell.WeaponType == "Tome") then
		damage *= 1 + ((player:GetAttribute("SpellPower") :: number?) or 0) -- robes and rings (ArmorService)
	end
	if weapon.Combo then
		local count = if last and now - last < weapon.Cooldown * 2.5 then (comboCount[player] or 0) + 1 else 1
		comboCount[player] = count
		if count % weapon.Combo == 0 then
			damage *= weapon.ComboBonus or 1
		end
	end

	local function roll(): (number, string)
		local amount = damage * (0.9 + math.random() * 0.2)
		if math.random() < weapon.CritChance then
			return amount * weapon.CritMultiplier, "Crit"
		end
		return amount, "Hit"
	end

	local function hit(enemy: Target)
		local amount, kind = roll()
		targets.Damage(enemy, amount, player, kind)
	end

	if not weapon.Swings then
		playSwing(tool, weapon.Anim)
	end
	-- The player's screen plays the swing; the blow lands (or the spell leaves) when the swing gets there.
	local release = weapon.Release or 0
	if release > 0 then
		task.wait(release)
		if humanoid.Health <= 0 or tool.Parent ~= character then
			return
		end
	end
	local origin = root.Position

	if weapon.Kind == "Melee" then
		local minDot = math.cos(math.rad((weapon.Arc or 90) / 2))
		for _, enemy in targets.GetAlive() do
			local offset = flat(enemy.Root.Position - origin)
			local distance = offset.Magnitude
			if distance <= weapon.Range + ENEMY_RADIUS and (distance < 2 or aim:Dot(offset.Unit) >= minDot) then
				hit(enemy)
			end
		end
	elseif weapon.Kind == "Blast" then
		local point: Vector3
		if aimPoint then
			local offset = (aimPoint :: Vector3) - origin
			point = if offset.Magnitude > weapon.Range then origin + offset.Unit * weapon.Range else aimPoint :: Vector3
		else
			point = origin + aim * math.min(weapon.Range, 18) - Vector3.new(0, 2.5, 0)
		end
		local from = muzzleOf(tool, origin + Vector3.new(0, 1.5, 0) + aim * 2)
		local travel = (point - from).Magnitude / (weapon.ProjectileSpeed or 70)
		local radius = weapon.Radius or 8
		effectRemote:FireAllClients("Fireball", from, point, travel)
		task.delay(travel, function()
			effectRemote:FireAllClients("Blast", point, radius)
			for _, enemy in targets.GetAlive() do
				if flat(enemy.Root.Position - point).Magnitude <= radius + ENEMY_RADIUS then
					hit(enemy)
				end
			end
		end)
	elseif weapon.Kind == "Mend" then
		-- A bolt of light at the enemy closest to the aim line...
		local width = weapon.Width or 3
		local target: Target? = nil
		local targetAlong = weapon.Range
		for _, enemy in targets.GetAlive() do
			local offset = flat(enemy.Root.Position - origin)
			local along = offset:Dot(aim)
			local across = (offset - aim * along).Magnitude
			if along > 0 and along < targetAlong and across <= width then
				target, targetAlong = enemy, along
			end
		end
		if target then
			local from = muzzleOf(tool, origin + Vector3.new(0, 1.5, 0) + aim * 1.5)
			local to = target.Root.Position
			local travel = (to - from).Magnitude / (weapon.ProjectileSpeed or 90)
			effectRemote:FireAllClients("Bolt", from, to, travel)
			local struck = target
			task.delay(travel, function()
				hit(struck)
			end)
		end

		-- ...and a heal for the most hurt player nearby (yourself counts, at a reduced rate).
		local patient: Humanoid? = nil
		local patientRoot: BasePart? = nil
		local lowest = 1
		for _, other in Players:GetPlayers() do
			local otherHumanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherHumanoid and otherRoot and otherHumanoid.Health > 0 then
				local ratio = otherHumanoid.Health / otherHumanoid.MaxHealth
				if ratio < lowest and (otherRoot.Position - origin).Magnitude <= (weapon.HealRange or 35) then
					patient, patientRoot, lowest = otherHumanoid, otherRoot, ratio
				end
			end
		end
		if patient and patientRoot then
			local amount = Items.WeaponHeal(item.Item, item.Rarity, item.Upgrade) * Leveling.DamageMultiplier(data.Level) * (1 + ((player:GetAttribute("SpellPower") :: number?) or 0))
			if patient == humanoid then
				amount *= weapon.SelfHeal or 1
			end
			local patientPlayer = Players:GetPlayerFromCharacter(patient.Parent)
			if patientPlayer then
				amount *= BlightService.HealMultiplier(patientPlayer)
			end
			local healed = math.max(1, math.floor(math.min(amount, patient.MaxHealth - patient.Health) + 0.5))
			patient.Health = math.min(patient.MaxHealth, patient.Health + healed)
			effectRemote:FireAllClients("Heal", patientRoot.Position)
			damageNumberRemote:FireAllClients(patientRoot.Position + Vector3.new(0, 2.5, 0), healed, "Heal")
		end
	end
end

function CombatService.Start(what: Targets)
	targets = what
	attackRemote.OnServerEvent:Connect(onAttack)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		comboCount[player] = nil
	end)
end

return CombatService
