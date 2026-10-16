--!strict
-- Emberhold's shops and the way down.
--   Brakka (Brakka's Forge): talking to her opens her shop. She sells health potions and plain weapons, and
--   while the shop is open the bag's button turns into Sell (InventoryService.SetAtShop), so loot and
--   monster materials can be sold. Walking away or closing the window closes the shop.
--   The Great Well (The Descent): takes the player down into the Depths (the dungeon place).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local InventoryService = require(Common.InventoryService)
local ProgressService = require(Common.ProgressService)
local RateLimiter = require(Common.RateLimiter)
local TownBuilder = require(script.Parent.TownBuilder)

local SHOP_RANGE = 16

export type Offer = { Item: string, Rarity: string, Price: number }

-- What each shopkeeper sells.
local STOCK: { [string]: { Title: string, Line: string, Offers: { Offer } } } = {
	Brakka = {
		Title = "Brakka's Forge",
		Line = "Don't just stand there dripping on my floor. Buying or selling?",
		Offers = {
			{ Item = "HealthPotion", Rarity = "Common", Price = 25 },
			{ Item = "RustySword", Rarity = "Common", Price = 60 },
			{ Item = "WoodcutterAxe", Rarity = "Common", Price = 150 },
			{ Item = "ApprenticeStaff", Rarity = "Common", Price = 150 },
			{ Item = "AcolyteTome", Rarity = "Common", Price = 150 },
			{ Item = "RustySword", Rarity = "Rare", Price = 650 },
			{ Item = "WoodcutterAxe", Rarity = "Rare", Price = 800 },
		},
	},
}

local ShopService = {}

local openShop: { [Player]: { Name: string, At: BasePart } } = {}
local buyLimiter = RateLimiter.new(0.25)

local function closeShop(player: Player)
	if openShop[player] then
		openShop[player] = nil
		InventoryService.SetAtShop(player, false)
	end
end

local function prompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.3
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

function ShopService.Start()
	local town = TownBuilder.Build()
	local openRemote = Remotes.Event("ShopOpen")
	local notifyRemote = Remotes.Event("Notify")

	-- Brakka's shop
	local trade = prompt(town.Brakka, "Trade", "Brakka")
	trade.Triggered:Connect(function(player)
		local stock = STOCK.Brakka
		openShop[player] = { Name = "Brakka", At = town.Brakka }
		InventoryService.SetAtShop(player, true)
		openRemote:FireClient(player, { Shop = "Brakka", Title = stock.Title, Line = stock.Line, Offers = stock.Offers })
	end)

	Remotes.Event("ShopBuy").OnServerEvent:Connect(function(player, index: any)
		local shop = openShop[player]
		local data = DataService.GetData(player)
		if not shop or not data or type(index) ~= "number" or not buyLimiter:Check(player) then
			return
		end
		local offer = STOCK[shop.Name].Offers[index]
		if not offer then
			return
		end
		if data.Gold < offer.Price then
			notifyRemote:FireClient(player, "Not enough gold.")
			return
		end
		if InventoryService.GiveItem(player, offer.Item, offer.Rarity, 1) > 0 then
			ProgressService.AddGold(player, -offer.Price)
		end
	end)
	Remotes.Event("ShopClose").OnServerEvent:Connect(closeShop)
	Players.PlayerRemoving:Connect(closeShop)

	-- walking away from the shopkeeper closes the shop
	RunService.Heartbeat:Connect(function()
		for player, shop in openShop do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - shop.At.Position).Magnitude > SHOP_RANGE then
				closeShop(player)
				openRemote:FireClient(player, nil)
			end
		end
	end)

	-- The Great Well: down into the Depths
	local descend = prompt(town.Well, "Descend", "The Great Well")
	descend.HoldDuration = 1
	descend.MaxActivationDistance = 14
	descend.Triggered:Connect(function(player)
		if RunService:IsStudio() then
			notifyRemote:FireClient(player, "The way down only opens in the published game (Studio can't teleport). Test the Depths in its own place.")
			return
		end
		DataService.SaveNow(player)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(Config.PlaceIds.Depths, { player })
		end)
		if not ok then
			warn(`[ShopService] Teleport to the Depths failed: {err}`)
			notifyRemote:FireClient(player, "The well's chains won't move. Try again in a moment.")
		end
	end)

	-- new arrivals come in at the south end of the square
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				character:PivotTo(town.Spawn)
			end)
		end)
	end)
end

return ShopService
