--!strict
-- Player attacks. The client only says "I attacked with this weapon, in this direction".
-- The server checks the weapon is really in the player's hand and off cooldown, then finds
-- the hits itself from where everything really is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Leveling = require(ReplicatedStorage.Shared.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local DataService = require(script.Parent.Parent.Common.DataService)
local InventoryService = require(script.Parent.Parent.Common.InventoryService)
local EnemyService = require(script.Parent.EnemyService)

local COOLDOWN_TOLERANCE = 0.85 -- accept attacks slightly early, for network jitter
local ENEMY_RADIUS = 1.5 -- an enemy's body counts as hit this far from its center

local CombatService = {}

local attackRemote = Remotes.Event("Attack")
local effectRemote = Remotes.Event("Effect")
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

	local function hit(enemy: EnemyService.Enemy)
		local amount, kind = roll()
		EnemyService.Damage(enemy, amount, player, kind)
		local poison = weapon.Poison
		if poison then
			task.spawn(function()
				for _ = 1, poison.Ticks do
					task.wait(poison.Interval)
					EnemyService.Damage(enemy, amount * poison.Fraction, player, "Poison")
				end
			end)
		end
	end

	playSwing(tool, weapon.Anim)
	local origin = root.Position

	if weapon.Kind == "Melee" then
		local minDot = math.cos(math.rad((weapon.Arc or 90) / 2))
		for _, enemy in EnemyService.GetAlive() do
			local offset = flat(enemy.Root.Position - origin)
			local distance = offset.Magnitude
			if distance <= weapon.Range + ENEMY_RADIUS and (distance < 2 or aim:Dot(offset.Unit) >= minDot) then
				hit(enemy)
			end
		end
	elseif weapon.Kind == "Line" then
		local width = weapon.Width or 3
		for _, enemy in EnemyService.GetAlive() do
			local offset = flat(enemy.Root.Position - origin)
			local along = offset:Dot(aim)
			local across = (offset - aim * along).Magnitude
			if along >= -1 and along <= weapon.Range + ENEMY_RADIUS and across <= width then
				hit(enemy)
			end
		end
	elseif weapon.Kind == "Arrow" then
		local width = weapon.Width or 2.5
		local target: EnemyService.Enemy? = nil
		local targetAlong = weapon.Range
		for _, enemy in EnemyService.GetAlive() do
			local offset = flat(enemy.Root.Position - origin)
			local along = offset:Dot(aim)
			local across = (offset - aim * along).Magnitude
			if along > 0 and along < targetAlong and across <= width then
				target, targetAlong = enemy, along
			end
		end
		local from = origin + Vector3.new(0, 1, 0) + aim * 1.5
		local to = if target then target.Root.Position else from + aim * weapon.Range
		local travel = (to - from).Magnitude / (weapon.ProjectileSpeed or 140)
		effectRemote:FireAllClients("Arrow", from, to, travel)
		if target then
			local struck = target
			task.delay(travel, function()
				hit(struck)
			end)
		end
	elseif weapon.Kind == "Blast" then
		local point: Vector3
		if aimPoint then
			local offset = (aimPoint :: Vector3) - origin
			point = if offset.Magnitude > weapon.Range then origin + offset.Unit * weapon.Range else aimPoint :: Vector3
		else
			point = origin + aim * math.min(weapon.Range, 18) - Vector3.new(0, 2.5, 0)
		end
		local from = origin + Vector3.new(0, 1.5, 0) + aim * 2
		local travel = (point - from).Magnitude / (weapon.ProjectileSpeed or 70)
		local radius = weapon.Radius or 8
		effectRemote:FireAllClients("Fireball", from, point, travel)
		task.delay(travel, function()
			effectRemote:FireAllClients("Blast", point, radius)
			for _, enemy in EnemyService.GetAlive() do
				if flat(enemy.Root.Position - point).Magnitude <= radius + ENEMY_RADIUS then
					hit(enemy)
				end
			end
		end)
	end
end

function CombatService.Start()
	attackRemote.OnServerEvent:Connect(onAttack)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		comboCount[player] = nil
	end)
end

return CombatService
