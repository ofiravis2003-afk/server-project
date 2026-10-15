--!strict
-- The player's items (the bag, Config.BagSize places), and the weapon Tool they carry.
-- The hotbar holds only the equipped weapon (slot 1); the rest waits in the bag, where the player
-- can equip or sell it. A new item that finds the bag full is sold on the spot.

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

export type Item = { Item: string, Rarity: string, Upgrade: number }

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

local function countItems(data: { [string]: any }): number
	local n = 0
	for _ in data.Inventory do
		n += 1
	end
	return n
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
		data.Equipped.Weapon = InventoryService.AddItem(data, "RustySword")
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
	if Config.TestMode then
		for _, itemName in Items.StarterWeapons do
			if not ownsItemNamed(data, itemName) then
				InventoryService.AddItem(data, itemName)
			end
		end
	end
end

-- The weapon ids to put in the hotbar: just the equipped weapon, in slot 1.
local function hotbarIds(data: { [string]: any }): { string }
	return if data.Equipped.Weapon then { data.Equipped.Weapon } else {}
end

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
		local name = Items.NameFor(item.Item, item.Rarity)
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
end

-- Gives a player a new item: saves it in the bag and shows them the "New item!" card.
-- With the bag full, it's sold right away for its gold.
function InventoryService.GiveItem(player: Player, itemName: string, rarity: string): string?
	local data = DataService.GetData(player)
	if not data or not Items.Defs[itemName] then
		return nil
	end
	itemReceivedRemote:FireClient(player, { Item = itemName, Rarity = rarity })
	if countItems(data) >= Config.BagSize then
		local price = Items.SellPrice(rarity, 0)
		ProgressService.AddGold(player, price)
		notifyRemote:FireClient(player, `Your bag is full: {Items.NameFor(itemName, rarity)} was sold for {price} gold.`)
		return nil
	end
	local id = InventoryService.AddItem(data, itemName, rarity)
	InventoryService.PushInventory(player)
	return id
end

-- The player asks to equip or sell an item from their bag.
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
	elseif action == "Sell" then
		if data.Equipped[def.Slot] == itemId then
			return -- what's in hand can't be sold; equip something else first
		end
		data.Inventory[itemId] = nil
		ProgressService.AddGold(player, Items.SellPrice(item.Rarity, item.Upgrade or 0))
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
end

return InventoryService
