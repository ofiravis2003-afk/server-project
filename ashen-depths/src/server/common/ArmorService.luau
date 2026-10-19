--!strict
-- Armor on the body, in both places.
--   * Every character gets the same body (Roblox's free "Man" body, at standard size), keeping the player's
--     face, skin, clothes and accessories, so armor sits the same on everyone. A human shape, not the blocky
--     one: real armor looks wrong on boxes.
--   * What's worn (data.Equipped Head / Chest / Hands / Legs / Ring) is dressed on the character: the Tripo
--     piece from ReplicatedStorage.ArmorModels when there is one, a plain stand-in otherwise. Hair and hats
--     hide under a helmet, jackets under a chest piece, shoes and trousers under boots.
--   * Its numbers (shared/Armor) go on the player: Defense (attribute, used by ArmorService.Hurt), max
--     health (attribute BonusHealth, read by ProgressService), walk speed, and SpellPower (attribute, read
--     by CombatService for staves and tomes).
-- A Tripo model in ArmorModels is prepared at the size of that body, with its WorldPivot where it
-- mounts: Head on the head's centre, Chest on the upper torso's, Hands on the right lower arm's, Legs on the
-- right lower leg's, all facing -Z. The left glove and boot are the right ones turned round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.Shared.Armor)
local Leveling = require(ReplicatedStorage.Shared.Leveling)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local DataService = require(script.Parent.DataService)

local ArmorService = {}

local BASE_SPEED = 16
-- the "Man" body (catalog bundle 238): torso, arms and legs; the head stays the player's own size
local BODY = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078 }
local ARMOR_SLOTS = { "Head", "Chest", "Hands", "Legs", "Ring" }

-- Accessories that would poke through each piece.
local HIDDEN_BY: { [string]: { Enum.AccessoryType } } = {
	Head = { Enum.AccessoryType.Hat, Enum.AccessoryType.Hair, Enum.AccessoryType.Face, Enum.AccessoryType.Eyebrow, Enum.AccessoryType.Eyelash },
	Chest = { Enum.AccessoryType.Back, Enum.AccessoryType.Shoulder, Enum.AccessoryType.Neck, Enum.AccessoryType.Front, Enum.AccessoryType.Waist, Enum.AccessoryType.Jacket, Enum.AccessoryType.Sweater, Enum.AccessoryType.Shirt, Enum.AccessoryType.TShirt },
	Legs = { Enum.AccessoryType.Pants, Enum.AccessoryType.Shorts, Enum.AccessoryType.DressSkirt, Enum.AccessoryType.LeftShoe, Enum.AccessoryType.RightShoe },
}

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
-- The same body for everyone

local normalizing: { [Model]: boolean } = {}

local function normalizeBody(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	if not player:HasAppearanceLoaded() then
		local loaded = false
		local connection = player.CharacterAppearanceLoaded:Connect(function()
			loaded = true
		end)
		local start = os.clock()
		while not loaded and os.clock() - start < 6 and character.Parent do
			task.wait(0.1)
		end
		connection:Disconnect()
	end
	if not character.Parent then
		return
	end
	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not description then
		return
	end
	local same = description.Head == 0 and description.Torso == BODY.Torso and description.LeftArm == BODY.LeftArm and description.RightArm == BODY.RightArm
		and description.LeftLeg == BODY.LeftLeg and description.RightLeg == BODY.RightLeg and description.HeightScale == 1 and description.WidthScale == 1
		and description.DepthScale == 1 and description.HeadScale == 1 and description.BodyTypeScale == 0 and description.ProportionScale == 0
	if same then
		return
	end
	description.Head = 0
	description.Torso = BODY.Torso
	description.LeftArm = BODY.LeftArm
	description.RightArm = BODY.RightArm
	description.LeftLeg = BODY.LeftLeg
	description.RightLeg = BODY.RightLeg
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	normalizing[character] = true
	pcall(function()
		humanoid:ApplyDescription(description)
	end)
	normalizing[character] = nil
end

------------------------------------------------------------------------------------------------
-- Dressing

local function weldTo(piece: Model, bodyPart: BasePart)
	for _, part in piece:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = bodyPart
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function block(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A plain stand-in in the set's colour, built round the body part, until the Tripo model is in.
local function standIn(setName: string, slot: string, bodyPart: BasePart, extra: BasePart?): Model
	local set = Armor.SetByName[setName]
	local color = set and set.Color or Color3.fromRGB(110, 110, 110)
	local material = if setName == "Heavy" or setName == "Medium" then Enum.Material.Metal elseif setName == "Light" then Enum.Material.Leather else Enum.Material.Fabric
	local model = Instance.new("Model")
	local cf, size = bodyPart.CFrame, bodyPart.Size
	if slot == "Head" then
		block(model, size * Vector3.new(1.18, 1.12, 1.18), cf * CFrame.new(0, 0.08, 0), color, material)
		if setName == "Heavy" then
			block(model, Vector3.new(size.X * 0.9, 0.12, 0.05), cf * CFrame.new(0, 0.1, -size.Z * 0.6), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic)
		end
	elseif slot == "Chest" then
		block(model, size * Vector3.new(1.1, 1.06, 1.2), cf, color, material)
		for _, side in { -1, 1 } do
			block(model, Vector3.new(0.9, 0.5, 1.15), cf * CFrame.new(side * (size.X / 2 + 0.25), size.Y / 2 - 0.15, 0), color, material)
		end
	elseif slot == "Hands" or slot == "Legs" then
		-- covers the lower arm (or leg) and the hand (or foot) under it
		block(model, size * Vector3.new(1.18, 1.02, 1.18), cf, color, material)
		if extra then
			block(model, extra.Size * Vector3.new(1.15, 1.25, 1.12), extra.CFrame, color, material)
		end
	end
	return model
end

-- Legendary pieces glow a little; Mythic ones also give off embers.
local function rarityTouch(piece: Model, rarity: string)
	if rarity ~= "Legendary" and rarity ~= "Mythic" then
		return
	end
	local main = piece:FindFirstChildWhichIsA("BasePart", true)
	if not main then
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

-- One piece on one side: the Tripo model mounted on the body part (turned round for the left side), or a
-- stand-in.
local function mount(folder: Folder, piece: Armor.Piece, rarity: string, bodyPart: BasePart, extra: BasePart?, left: boolean)
	local models = ReplicatedStorage:FindFirstChild("ArmorModels")
	local source = models and piece.Look and models:FindFirstChild(piece.Look)
	local model: Model
	if source and source:IsA("Model") then
		model = source:Clone()
		local turn = if left then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		model:PivotTo(bodyPart.CFrame * turn)
	else
		model = standIn(piece.Set, piece.Slot, bodyPart, extra)
	end
	model.Name = piece.Slot .. (if left then "Left" else "")
	rarityTouch(model, rarity)
	weldTo(model, bodyPart)
	model.Parent = folder
end

local function setHidden(character: Model, slot: string, hidden: boolean)
	local types = HIDDEN_BY[slot]
	if not types then
		return
	end
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and table.find(types, accessory.AccessoryType) then
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

local function dress(character: Model, worn: { [string]: { Item: string, Rarity: string, Upgrade: number? } })
	local old = character:FindFirstChild("Armor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Armor"
	for _, slot in Armor.BodySlots do
		local item = worn[slot]
		local piece = item and Armor.Pieces[item.Item]
		setHidden(character, slot, piece ~= nil)
		if item and piece then
			if slot == "Head" then
				local head = character:FindFirstChild("Head") :: BasePart?
				if head then
					mount(folder, piece, item.Rarity, head, nil, false)
				end
			elseif slot == "Chest" then
				local torso = character:FindFirstChild("UpperTorso") :: BasePart?
				if torso then
					mount(folder, piece, item.Rarity, torso, nil, false)
				end
			else
				local upper, lower = if slot == "Hands" then "LowerArm" else "LowerLeg", if slot == "Hands" then "Hand" else "Foot"
				for _, side in { "Right", "Left" } do
					local part = character:FindFirstChild(side .. upper) :: BasePart?
					local under = character:FindFirstChild(side .. lower) :: BasePart?
					if part then
						mount(folder, piece, item.Rarity, part, under, side == "Left")
					end
				end
			end
		end
	end
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

-- After the player equips or takes off armor, or on a new character: dress them and apply the numbers.
function ArmorService.Refresh(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local worn = wornItems(data)
	local character = player.Character
	if character and not normalizing[character] then
		dress(character, worn)
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
			normalizeBody(player, character)
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
