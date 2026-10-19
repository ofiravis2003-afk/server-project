--!strict
-- The player's items (the bag, Config.BagSize places), and the Tools on their hotbar.
-- Hotbar: slot 1 is the equipped weapon, slots 2-4 the potions they carry (taking one out drinks it, and the
-- weapon comes back to hand). The rest waits in the bag, where the player can equip it or drop it.
-- Materials and potions stack in one bag place (Items Stack); potions also have a carry limit (Items Limit). Selling only happens at a merchant in Emberhold: the shop marks the player
-- with "AtShop" (set here on the server, so it can't be faked). A new item that finds the bag full is left behind.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponBuilder = require(ReplicatedStorage.Shared.WeaponBuilder)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local RateLimiter = require(script.Parent.RateLimiter)

local TOOL_TAG = "WeaponTool"

export type Item = { Item: string, Rarity: string, Upgrade: number, Count: number? }

local POTION_COOLDOWN = 10

local InventoryService = {}

-- Adds a new item to the player's save and returns its id.
function InventoryService.AddItem(data: { [string]: any }, itemName: string, rarity: string?): string
	local id = tostring(data.NextItemId)
	data.NextItemId += 1
	data.Inventory[id] = { Item = itemName, Rarity = rarity or "Common", Upgrade = 0 }
	return id
end

local itemReceivedRemote = Remotes.Event("ItemReceived")
local inventoryRemote = Remotes.Event("InventoryUpdated")
local actionRemote = Remotes.Event("InventoryAction")
local notifyRemote = Remotes.Event("Notify")
local actionLimiter = RateLimiter.new(0.2)
local damageNumberRemote = Remotes.Event("DamageNumber")
local nextPotion: { [Player]: number } = {}

local function countItems(data: { [string]: any }): number
	local n = 0
	for _ in data.Inventory do
		n += 1
	end
	return n
end

-- How many of `itemName` the player has in all.
local function countOf(data: { [string]: any }, itemName: string): number
	local n = 0
	for _, item in data.Inventory do
		if item.Item == itemName then
			n += item.Count or 1
		end
	end
	return n
end

-- Puts `count` of an item in the bag: onto stacks that have room first, then into new places.
-- Returns how many went in (fewer when the bag is full or the carry limit is reached).
local function addToBag(data: { [string]: any }, itemName: string, rarity: string, count: number): number
	local def = Items.Defs[itemName]
	local stack = def.Stack or 1
	local left = count
	if def.Limit then
		left = math.min(left, def.Limit - countOf(data, itemName))
	end
	if stack > 1 then
		for _, item in data.Inventory do
			if left <= 0 then
				break
			end
			if item.Item == itemName and (item.Count or 1) < stack then
				local put = math.min(left, stack - (item.Count or 1))
				item.Count = (item.Count or 1) + put
				left -= put
			end
		end
	end
	while left > 0 and countItems(data) < Config.BagSize do
		local id = InventoryService.AddItem(data, itemName, rarity)
		local put = math.min(left, stack)
		if stack > 1 then
			data.Inventory[id].Count = put
		end
		left -= put
	end
	return count - math.max(left, 0)
end

-- How many of `itemName` a player carries (all stacks).
function InventoryService.CountOf(player: Player, itemName: string): number
	local data = DataService.GetData(player)
	return if data then countOf(data, itemName) else 0
end

-- Takes `count` of a stacked item out of the player's bag. Returns false (and takes nothing) if they have fewer.
function InventoryService.Take(player: Player, itemName: string, count: number): boolean
	local data = DataService.GetData(player)
	if not data or countOf(data, itemName) < count then
		return false
	end
	local left = count
	for id, item in data.Inventory do
		if left <= 0 then
			break
		end
		if item.Item == itemName then
			local here = item.Count or 1
			local take = math.min(here, left)
			left -= take
			if here - take <= 0 then
				data.Inventory[id] = nil
			else
				item.Count = here - take
			end
		end
	end
	return true
end

-- Sends the player what's in their bag and what they have equipped.
function InventoryService.PushInventory(player: Player)
	local data = DataService.GetData(player)
	if data then
		inventoryRemote:FireClient(player, { Items = data.Inventory, Equipped = data.Equipped, BagSize = Config.BagSize })
	end
end

-- Returns the player's item and its definition, or nil if they don't own it.
function InventoryService.GetItem(player: Player, itemId: string): (Item?, Items.ItemDef?)
	local data = DataService.GetData(player)
	local item = data and data.Inventory[itemId]
	if not item then
		return nil, nil
	end
	return item, Items.Defs[item.Item]
end

local function ownsItemNamed(data: { [string]: any }, itemName: string): boolean
	for _, item in data.Inventory do
		if item.Item == itemName then
			return true
		end
	end
	return false
end

local function giveStarterItems(data: { [string]: any })
	-- Items that were taken out of the game (like the old Iron Spear) leave the save.
	for id, item in data.Inventory do
		if not Items.Defs[item.Item] then
			data.Inventory[id] = nil
		end
	end
	for slot, id in data.Equipped do
		if not data.Inventory[id] then
			data.Equipped[slot] = nil
		end
	end
	if not data.Equipped.Weapon then
		for id, item in data.Inventory do
			if Items.Defs[item.Item].Slot == "Weapon" then
				data.Equipped.Weapon = id
				break
			end
		end
	end

	if next(data.Inventory) == nil then
		-- A brand-new adventurer: a rusty sword and two health potions.
		data.Equipped.Weapon = InventoryService.AddItem(data, "RustySword")
		addToBag(data, "HealthPotion", "Common", 2)
	end
	if Config.TestMode and Config.TestLoadout then
		-- A test set of weapons replaces everything, once for each different set (so loot found afterwards stays).
		local parts = {}
		for _, entry in Config.TestLoadout do
			table.insert(parts, `{entry.Item}:{entry.Rarity}`)
		end
		local key = table.concat(parts, ",")
		if data.AppliedTestLoadout ~= key then
			data.AppliedTestLoadout = key
			data.Inventory = {}
			data.Equipped = {}
			for _, entry in Config.TestLoadout do
				local id = InventoryService.AddItem(data, entry.Item, entry.Rarity)
				data.Equipped.Weapon = data.Equipped.Weapon or id
			end
			return
		end
	end
	if Config.TestMode and countOf(data, "HealthPotion") == 0 then
		addToBag(data, "HealthPotion", "Common", 3)
	end
	if Config.TestMode then
		for _, itemName in Items.StarterWeapons do
			if not ownsItemNamed(data, itemName) then
				InventoryService.AddItem(data, itemName)
			end
		end
	end
end

-- The weapon id for hotbar slot 1: just the equipped weapon.
local function hotbarIds(data: { [string]: any }): { string }
	return if data.Equipped.Weapon then { data.Equipped.Weapon } else {}
end

-- The kinds of potion the player carries, for hotbar slots 2-4 (one slot per kind).
local function potionKinds(data: { [string]: any }): { string }
	local kinds, seen = {}, {}
	for _, item in data.Inventory do
		local def = Items.Defs[item.Item]
		if def and def.Slot == "Potion" and not seen[item.Item] then
			seen[item.Item] = true
			table.insert(kinds, item.Item)
		end
	end
	table.sort(kinds)
	return kinds
end

local drinkPotion: (Player, string) -> ()

-- Rebuilds the player's weapon Tools from their save. A weapon that was in hand is put back in hand.
function InventoryService.RefreshTools(player: Player)
	local data = DataService.GetData(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not character or not backpack then
		return
	end
	local wasHolding = false
	for _, child in character:GetChildren() do
		if CollectionService:HasTag(child, TOOL_TAG) then
			wasHolding = true
		end
	end

	for _, container in { backpack, character } do
		for _, child in container:GetChildren() do
			if CollectionService:HasTag(child, TOOL_TAG) then
				child:Destroy()
			end
		end
	end

	for _, id in hotbarIds(data) do
		local item = data.Inventory[id]
		local def = Items.Defs[item.Item]
		local tool = WeaponBuilder.Build(def.Look or "Sword", item.Rarity)
		local name = Items.NameFor(item.Item, item.Rarity) .. (if (item.Upgrade or 0) > 0 then ` +{item.Upgrade}` else "")
		tool.Name = name
		tool.ToolTip = `{name} ({item.Rarity})`
		tool:SetAttribute("ItemId", id)
		tool:SetAttribute("WeaponType", def.WeaponType)
		CollectionService:AddTag(tool, TOOL_TAG)
		local offHand = tool:FindFirstChild("OffHand") :: BasePart?
		if offHand then
			-- Held in the left hand: welded there while the weapon is out.
			tool.Equipped:Connect(function()
				local hand = character:FindFirstChild("LeftHand") :: BasePart?
				local grip = hand and hand:FindFirstChild("LeftGripAttachment") :: Attachment?
				local frame = offHand:FindFirstChild("WeaponGrip") :: Attachment?
				if hand and grip and frame then
					local weld = Instance.new("Weld")
					weld.Name = "OffHandGrip"
					weld.Part0 = hand
					weld.Part1 = offHand
					weld.C0 = grip.CFrame
					weld.C1 = frame.CFrame
					weld.Parent = offHand
				end
			end)
			tool.Unequipped:Connect(function()
				local weld = offHand:FindFirstChild("OffHandGrip")
				if weld then
					weld:Destroy()
				end
			end)
		end
		tool.Parent = backpack
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if wasHolding and humanoid and humanoid.Health > 0 then
			humanoid:EquipTool(tool)
			wasHolding = false
		end
	end

	-- Potions: taking one out of the hotbar drinks it.
	for i, itemName in potionKinds(data) do
		if i > Config.HotbarSize - 1 then
			break
		end
		local def = Items.Defs[itemName]
		local potion = Instance.new("Tool")
		potion.Name = `{def.DisplayName} ({countOf(data, itemName)})`
		potion.ToolTip = def.Description or def.DisplayName
		potion.RequiresHandle = false
		potion.CanBeDropped = false
		potion:SetAttribute("Potion", itemName)
		CollectionService:AddTag(potion, TOOL_TAG)
		potion.Equipped:Connect(function()
			drinkPotion(player, itemName)
		end)
		potion.Parent = backpack
	end
end

-- Drinks one potion (if it's ready and does something), then puts the weapon back in hand.
drinkPotion = function(player: Player, itemName: string)
	local data = DataService.GetData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local def = Items.Defs[itemName]
	local now = os.clock()
	if data and humanoid and humanoid.Health > 0 and def and countOf(data, itemName) > 0 then
		if (nextPotion[player] or 0) > now then
			notifyRemote:FireClient(player, `Not yet: {math.ceil((nextPotion[player] :: number) - now)}s until the next potion.`)
		elseif def.HealFraction and humanoid.Health >= humanoid.MaxHealth then
			notifyRemote:FireClient(player, "You're already at full health.")
		else
			nextPotion[player] = now + POTION_COOLDOWN
			for id, item in data.Inventory do
				if item.Item == itemName then
					item.Count = (item.Count or 1) - 1
					if item.Count <= 0 then
						data.Inventory[id] = nil
					end
					break
				end
			end
			if def.HealFraction then
				local heal = math.floor(humanoid.MaxHealth * def.HealFraction)
				humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					damageNumberRemote:FireClient(player, root.Position + Vector3.new(0, 3, 0), heal, "Heal")
					local sparkle = Instance.new("ParticleEmitter")
					sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 90, 100), Color3.fromRGB(255, 200, 200))
					sparkle.LightEmission = 0.8
					sparkle.Size = NumberSequence.new(0.35, 0)
					sparkle.Lifetime = NumberRange.new(0.6, 1)
					sparkle.Speed = NumberRange.new(2, 4)
					sparkle.SpreadAngle = Vector2.new(180, 180)
					sparkle.Acceleration = Vector3.new(0, 5, 0)
					sparkle.Parent = root
					sparkle:Emit(30)
					task.delay(1.2, function()
						sparkle:Destroy()
					end)
				end
			end
			InventoryService.PushInventory(player)
		end
	end
	task.defer(InventoryService.RefreshTools, player)
end

-- Gives a player `count` (default 1) of an item: into the bag, with the "New item!" card for gear and potions
-- (materials only get the floating "+1 Bone" the caller shows). What doesn't fit is left behind.
-- Returns how many went in.
function InventoryService.GiveItem(player: Player, itemName: string, rarity: string, count: number?): number
	local data = DataService.GetData(player)
	local def = Items.Defs[itemName]
	if not data or not def then
		return 0
	end
	local wanted = count or 1
	local added = addToBag(data, itemName, rarity, wanted)
	if added > 0 and def.Slot ~= "Material" then
		itemReceivedRemote:FireClient(player, { Item = itemName, Rarity = rarity })
	end
	if added < wanted then
		local reason = if def.Limit and countOf(data, itemName) >= def.Limit
			then `You can't carry more than {def.Limit} {def.DisplayName}s.`
			else `Your bag is full! {Items.NameFor(itemName, rarity)} was left behind. Drop something to make room.`
		notifyRemote:FireClient(player, reason)
	end
	if added > 0 then
		InventoryService.PushInventory(player)
		if def.Slot == "Potion" then
			InventoryService.RefreshTools(player)
		end
	end
	return added
end

-- A merchant's shop opens (true) or closes (false) for a player; only then can they sell.
function InventoryService.SetAtShop(player: Player, open: boolean)
	player:SetAttribute("AtShop", if open then true else nil)
end

-- The player asks to equip, sell (at a merchant) or drop an item from their bag.
local function onAction(player: Player, action: any, itemId: any)
	if not actionLimiter:Check(player) or type(itemId) ~= "string" then
		return
	end
	local data = DataService.GetData(player)
	local item = data and data.Inventory[itemId]
	local def = item and Items.Defs[item.Item]
	if not data or not item or not def then
		return
	end
	if action == "Equip" then
		if def.Slot == "Weapon" and data.Equipped.Weapon ~= itemId then
			data.Equipped.Weapon = itemId
			InventoryService.RefreshTools(player)
		end
	elseif action == "Sell" or action == "Drop" then
		if data.Equipped[def.Slot] == itemId or def.Keepsake then
			return -- what's in hand can't be sold or dropped; equip something else first
		end
		if action == "Sell" and not player:GetAttribute("AtShop") then
			return -- only at a merchant in Emberhold
		end
		data.Inventory[itemId] = nil
		if action == "Sell" then
			ProgressService.AddGold(player, Items.SellPrice(item.Item, item.Rarity, item.Upgrade or 0, item.Count))
		end
		if def.Slot == "Potion" then
			InventoryService.RefreshTools(player)
		end
	else
		return
	end
	InventoryService.PushInventory(player)
end

function InventoryService.Start()
	DataService.OnLoaded(function(player, data)
		giveStarterItems(data)
		player.CharacterAdded:Connect(function(character)
			player:WaitForChild("Backpack")
			character:WaitForChild("Humanoid")
			InventoryService.RefreshTools(player)
		end)
		InventoryService.RefreshTools(player)
		InventoryService.PushInventory(player)
	end)
	actionRemote.OnServerEvent:Connect(onAction)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		nextPotion[player] = nil
	end)
end

return InventoryService
