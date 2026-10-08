--!strict
-- The player's items, and the weapon Tools they carry.
-- Normal play: only the equipped weapon is in the hotbar. Test mode: one of every weapon type.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local WeaponBuilder = require(ReplicatedStorage.Shared.WeaponBuilder)
local DataService = require(script.Parent.DataService)

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
	if next(data.Inventory) == nil then
		data.Equipped.Weapon = InventoryService.AddItem(data, "RustySword")
	end
	if Config.TestMode then
		for _, itemName in Items.StarterWeapons do
			if not ownsItemNamed(data, itemName) then
				InventoryService.AddItem(data, itemName)
			end
		end
	end
end

-- The weapon ids to put in the hotbar, in order.
local function hotbarIds(data: { [string]: any }): { string }
	if not Config.TestMode then
		return if data.Equipped.Weapon then { data.Equipped.Weapon } else {}
	end
	local order = {}
	for index, itemName in Items.StarterWeapons do
		order[itemName] = index
	end
	local ids = {}
	for id, item in data.Inventory do
		local def = Items.Defs[item.Item]
		if def and def.Slot == "Weapon" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local orderA = order[data.Inventory[a].Item] or 99
		local orderB = order[data.Inventory[b].Item] or 99
		if orderA ~= orderB then
			return orderA < orderB
		end
		return tonumber(a) :: number < tonumber(b) :: number
	end)
	return ids
end

-- Rebuilds the player's weapon Tools from their save.
function InventoryService.RefreshTools(player: Player)
	local data = DataService.GetData(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not character or not backpack then
		return
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
		local tool = WeaponBuilder.Build(def.Look or "Sword")
		tool.Name = def.DisplayName
		tool.ToolTip = `{def.DisplayName} ({item.Rarity})`
		tool:SetAttribute("ItemId", id)
		tool:SetAttribute("WeaponType", def.WeaponType)
		CollectionService:AddTag(tool, TOOL_TAG)
		tool.Parent = backpack
	end
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
	end)
end

return InventoryService
