--!strict
-- Armor, in both places.
--   * Only the helmet is seen on the character (decided 2026-10-19: rigid chest, glove and boot pieces left
--     gaps at every joint on Roblox bodies). It's the Tripo model from ReplicatedStorage.ArmorModels, fitted
--     to the player's own head, with hats and hair hidden under it. Players keep their own avatar.
--   * Every worn piece (data.Equipped Head / Chest / Hands / Legs / Ring) still counts: its numbers
--     (shared/Armor) go on the player: Defense (attribute, used by ArmorService.Hurt), max health (attribute
--     BonusHealth, read by ProgressService), walk speed, and SpellPower (attribute, read by CombatService for
--     staves and tomes).
-- A helmet in ArmorModels is sized for a standard head (1.16 x 1.18 x 1.16) with its WorldPivot on the head's
-- centre, facing -Z; a bigger or smaller head gets it stretched to match.
-- Body pieces that have been made into layered clothing (ReplicatedStorage.ArmorLayered[Look], an Accessory
-- with a WrapLayer and cages, built with tools/retarget/layer_armor.py) are worn too: Roblox fits them to
-- any avatar and bends them with it, so they show no gaps (2026-10-20). Pieces without one stay unseen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.Shared.Armor)
local Leveling = require(ReplicatedStorage.Shared.Leveling)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local DataService = require(script.Parent.DataService)

local ArmorService = {}

local BASE_SPEED = 16
local STANDARD_HEAD = Vector3.new(1.16, 1.18, 1.16)
local ARMOR_SLOTS = { "Head", "Chest", "Hands", "Legs", "Ring" }
-- what would poke through a helmet
local UNDER_HELMET = { Enum.AccessoryType.Hat, Enum.AccessoryType.Hair, Enum.AccessoryType.Face, Enum.AccessoryType.Eyebrow, Enum.AccessoryType.Eyelash }

local function wornItems(data: { [string]: any }): { [string]: { Item: string, Rarity: string, Upgrade: number? } }
	local worn = {}
	for _, slot in ARMOR_SLOTS do
		local id = data.Equipped[slot]
		local item = id and data.Inventory[id]
		if item and Armor.Pieces[item.Item] then
			worn[slot] = item
		end
	end
	return worn
end

------------------------------------------------------------------------------------------------
-- The helmet

-- Legendary helmets glow a little; Mythic ones also give off embers.
local function rarityTouch(main: BasePart, rarity: string)
	if rarity ~= "Legendary" and rarity ~= "Mythic" then
		return
	end
	local info = Rarity.Info[rarity]
	local glow = Instance.new("PointLight")
	glow.Color = info.Color
	glow.Range = 5
	glow.Brightness = 0.6
	glow.Parent = main
	if rarity == "Mythic" then
		local embers = Instance.new("ParticleEmitter")
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 80), info.Color)
		embers.LightEmission = 1
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(0.6, 1.2)
		embers.Rate = 6
		embers.Speed = NumberRange.new(0.3, 0.8)
		embers.SpreadAngle = Vector2.new(180, 180)
		embers.Acceleration = Vector3.new(0, 2, 0)
		embers.Parent = main
	end
end

local function hideUnderHelmet(character: Model, hidden: boolean)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and table.find(UNDER_HELMET, accessory.AccessoryType) then
			for _, part in accessory:GetDescendants() do
				if part:IsA("BasePart") then
					if hidden then
						if part:GetAttribute("ShownTransparency") == nil then
							part:SetAttribute("ShownTransparency", part.Transparency)
						end
						part.Transparency = 1
					elseif part:GetAttribute("ShownTransparency") ~= nil then
						part.Transparency = part:GetAttribute("ShownTransparency")
						part:SetAttribute("ShownTransparency", nil)
					end
				end
			end
		end
	end
end

-- The layered body pieces: whatever is worn and has a garment goes on; the rest come off.
local function dressLayered(character: Model, worn: { [string]: { Item: string, Rarity: string, Upgrade: number? } })
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute("ArmorPiece") then
			child:Destroy()
		end
	end
	local garments = ReplicatedStorage:FindFirstChild("ArmorLayered")
	for _, slot in { "Head", "Chest", "Hands", "Legs" } do
		local item = worn[slot]
		local piece = item and Armor.Pieces[item.Item]
		local garment = piece and piece.Look and garments and garments:FindFirstChild(piece.Look)
		if item and garment and garment:IsA("Accessory") then
			local accessory = garment:Clone()
			accessory:SetAttribute("ArmorPiece", slot)
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				rarityTouch(handle, item.Rarity)
			end
			humanoid:AddAccessory(accessory)
		end
	end
end

local function dress(character: Model, helmet: { Item: string, Rarity: string, Upgrade: number? }?)
	local old = character:FindFirstChild("Armor")
	if old then
		old:Destroy()
	end
	local piece = helmet and Armor.Pieces[helmet.Item]
	local models = ReplicatedStorage:FindFirstChild("ArmorModels")
	local garments = ReplicatedStorage:FindFirstChild("ArmorLayered")
	-- a hood made into layered clothing is worn as one (dressLayered); only rigid helmets go on here
	local layered = piece and piece.Look and garments and garments:FindFirstChild(piece.Look)
	local source = if layered then nil else piece and piece.Look and models and models:FindFirstChild(piece.Look)
	local head = character:FindFirstChild("Head") :: BasePart?
	hideUnderHelmet(character, (source ~= nil or layered ~= nil) and head ~= nil)
	if not helmet or not source or not source:IsA("Model") or not head then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Armor"
	local model = source:Clone()
	model.Name = "Helmet"
	-- stretched to this head: each part's size and its place from the pivot, per axis
	local ratio = head.Size / STANDARD_HEAD
	local pivot = model:GetPivot()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local local_ = pivot:ToObjectSpace(part.CFrame)
			part.Size *= ratio
			part.CFrame = pivot * (local_.Rotation + local_.Position * ratio)
		end
	end
	model:PivotTo(head.CFrame)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	local main = model:FindFirstChildWhichIsA("BasePart", true)
	if main then
		rarityTouch(main, helmet.Rarity)
	end
	model.Parent = folder
	folder.Parent = character
end

------------------------------------------------------------------------------------------------
-- Numbers

local function applyStats(player: Player, worn: { [string]: { Item: string, Rarity: string, Upgrade: number? } })
	local list = {}
	for _, item in worn do
		table.insert(list, item)
	end
	local total = Armor.Total(list)
	player:SetAttribute("Defense", total.Defense)
	player:SetAttribute("SpellPower", total.SpellPower)
	player:SetAttribute("BonusHealth", math.floor(total.Health + 0.5))
	player:SetAttribute("SpeedBonus", total.Speed)
	local data = DataService.GetData(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and data and humanoid.Health > 0 then
		local fraction = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		humanoid.MaxHealth = Leveling.MaxHealth(data.Level) + math.floor(total.Health + 0.5)
		humanoid.Health = math.max(1, humanoid.MaxHealth * fraction)
		if humanoid.WalkSpeed > 0 then -- 0 while talking or watching a boss's entrance
			humanoid.WalkSpeed = BASE_SPEED * (1 + total.Speed)
		end
	end
end

-- After the player equips or takes off armor, or on a new character: the helmet on, and the numbers applied.
function ArmorService.Refresh(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local worn = wornItems(data)
	if player.Character then
		dress(player.Character, worn.Head)
		dressLayered(player.Character, worn)
	end
	applyStats(player, worn)
end

-- Damage to a player, lowered by their Defense. Returns what was dealt (for the damage number).
function ArmorService.Hurt(humanoid: Humanoid, amount: number): number
	local player = humanoid.Parent and Players:GetPlayerFromCharacter(humanoid.Parent)
	local defense = if player then (player:GetAttribute("Defense") :: number?) or 0 else 0
	local damage = math.max(1, math.floor(Armor.Reduce(amount, defense) + 0.5))
	humanoid:TakeDamage(damage)
	return damage
end

function ArmorService.Start()
	local function onCharacter(player: Player, character: Model)
		task.spawn(function()
			-- hats and hair arrive with the appearance; wait for it so they can be hidden under a helmet
			if not player:HasAppearanceLoaded() then
				local start = os.clock()
				while not player:HasAppearanceLoaded() and os.clock() - start < 6 and character.Parent do
					task.wait(0.1)
				end
			end
			if character.Parent then
				ArmorService.Refresh(player)
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	DataService.OnLoaded(function(player, _data)
		ArmorService.Refresh(player)
	end)
end

return ArmorService
