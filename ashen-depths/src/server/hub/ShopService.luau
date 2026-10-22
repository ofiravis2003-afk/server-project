--!strict
-- Emberhold's shops and the way down.
--   Brakka (Brakka's Forge): talking to her opens her shop. She sells health potions and plain weapons, and
--   while the shop is open the bag's button turns into Sell (InventoryService.SetAtShop), so loot and
--   monster materials can be sold. Walking away or closing the window closes the shop.
--   Brakka also upgrades weapons (+1 .. +10) for gold and monster materials (shared/Upgrades); from +6 an
--   upgrade can fail, losing what was paid but never the weapon.
--   The Great Well (The Descent): takes the player down into the Depths (the dungeon place).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Dialogues = require(ReplicatedStorage.Shared.Dialogues)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local InventoryService = require(Common.InventoryService)
local ProgressService = require(Common.ProgressService)
local QuestService = require(Common.QuestService)
local RateLimiter = require(Common.RateLimiter)
local Quests = require(ReplicatedStorage.Shared.Quests)
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
	-- Thorne's armory: every set's pieces (Common), a Rare chest piece of each, and the two rings
	Thorne = {
		Title = "Ironhide Armory",
		Line = "Armor won't make you brave. It'll just keep you alive long enough to learn.",
		Offers = (function()
			local offers = {}
			local price = { Head = 120, Chest = 220, Hands = 90, Legs = 110 }
			for _, set in { "Heavy", "Medium", "Light", "Robes" } do
				for _, slot in { "Head", "Chest", "Hands", "Legs" } do
					table.insert(offers, { Item = set .. slot, Rarity = "Common", Price = price[slot] })
				end
			end
			for _, set in { "Heavy", "Medium", "Light", "Robes" } do
				table.insert(offers, { Item = set .. "Chest", Rarity = "Rare", Price = 900 })
			end
			table.insert(offers, { Item = "SignetRing", Rarity = "Common", Price = 400 })
			table.insert(offers, { Item = "EmberBand", Rarity = "Common", Price = 450 })
			return offers
		end)(),
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

	-- a shopkeeper's window (Brakka's forge, Thorne's armory); closes when the player walks away from `at`
	local function openStore(player: Player, name: string, at: BasePart)
		local stock = STOCK[name]
		openShop[player] = { Name = name, At = at }
		InventoryService.SetAtShop(player, true)
		openRemote:FireClient(player, { Shop = name, Title = stock.Title, Line = stock.Line, Offers = stock.Offers })
	end
	local function openBrakka(player: Player)
		openStore(player, "Brakka", town.Brakka)
	end

	-- Talking to the townsfolk (their words in shared/Dialogues; Brakka's Trade opens her shop)
	local dialogueRemote = Remotes.Event("DialogueOpen")
	for key, d in Dialogues do
		local person = town.Model:FindFirstChild(key, true)
		local at = person and person:IsA("Model") and (person.PrimaryPart or person:FindFirstChildWhichIsA("BasePart", true))
		if at then
			local talk = prompt(at, "Talk", d.Name)
			talk.Triggered:Connect(function(player)
				dialogueRemote:FireClient(player, person)
			end)
		end
	end
	Remotes.Event("DialogueAction").OnServerEvent:Connect(function(player, key: any, action: any)
		local person = type(key) == "string" and town.Model:FindFirstChild(key, true)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not person or not person:IsA("Model") or not root or (root.Position - person:GetPivot().Position).Magnitude > SHOP_RANGE then
			return
		end
		if key == "Brakka" and action == "Trade" then
			openBrakka(player)
		elseif key == "Thorne" and action == "Trade" then
			local at = person.PrimaryPart or person:FindFirstChildWhichIsA("BasePart", true)
			if at then
				openStore(player, "Thorne", at)
			end
		elseif action == "Quests" and (key == "Aldric" or key == "OldPip" or key == "Seraphine") then
			QuestService.SetGiver(player, key)
			QuestService.Push(player)
			Remotes.Event("QuestBoardOpen"):FireClient(player, true, key)
		end
	end)

	-- The quest board by the Guild Hall opens the same window; walking away from the Guild closes it.
	local board = town.Model:FindFirstChild("QuestBoard", true)
	local aldric = town.Model:FindFirstChild("Aldric", true)
	local boardPart = board and board:FindFirstChildWhichIsA("BasePart", true)
	if boardPart then
		local read = prompt(boardPart, "Read", "Quest Board")
		read.Triggered:Connect(function(player)
			QuestService.SetGiver(player, "Aldric")
			QuestService.Push(player)
			Remotes.Event("QuestBoardOpen"):FireClient(player, true, "Aldric")
		end)
	end
	-- the Wall of the Fallen beside it
	local wall = town.Model:FindFirstChild("WallOfTheFallen", true)
	local slab = wall and wall:FindFirstChild("Slab") :: BasePart?
	if slab then
		local read = prompt(slab, "Read", "Wall of the Fallen")
		read.Triggered:Connect(function(player)
			Remotes.Event("Notify"):FireClient(player, "The names of adventurers who never came back up. Hundreds of them. The oldest row is worn almost smooth: one of the names reads \"A. Vane\".")
		end)
	end

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local giver = player:GetAttribute("QuestGiver")
			if giver then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = false
				for _, spot in (if giver == "Aldric" then { board, aldric } else { town.Model:FindFirstChild(giver, true) }) do
					if root and spot and spot:IsA("Model") and (root.Position - spot:GetPivot().Position).Magnitude <= SHOP_RANGE + 4 then
						near = true
					end
				end
				if not near then
					QuestService.SetGiver(player, nil)
					Remotes.Event("QuestBoardOpen"):FireClient(player, false)
				end
			end
		end
	end)

	-- each player's Guild rank over their head, in its color
	local function rankTag(player: Player, character: Model)
		local head = character:WaitForChild("Head", 10) :: BasePart?
		if not head then
			return
		end
		local tag = Instance.new("BillboardGui")
		tag.Name = "RankTag"
		tag.Size = UDim2.fromOffset(160, 22)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 60
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Fondamento
		text.TextSize = 18
		text.TextStrokeTransparency = 0.3
		text.Parent = tag
		local function refresh()
			local label = (player:GetAttribute("GuildRank") :: string?) or "Copper I"
			text.Text = label
			text.TextColor3 = Quests.ColorOf(string.split(label, " ")[1])
		end
		refresh()
		player:GetAttributeChangedSignal("GuildRank"):Connect(refresh)
		tag.Parent = head
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			rankTag(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		if player.Character then
			task.spawn(rankTag, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			rankTag(player, character)
		end)
	end

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

	-- Brakka's upgrades
	local upgradeResult = Remotes.Event("UpgradeResult")
	local upgradeLimiter = RateLimiter.new(0.6)
	Remotes.Event("UpgradeItem").OnServerEvent:Connect(function(player, itemId: any)
		local shop = openShop[player]
		local data = DataService.GetData(player)
		if not shop or shop.Name ~= "Brakka" or not data or type(itemId) ~= "string" or not upgradeLimiter:Check(player) then
			return
		end
		local item = data.Inventory[itemId]
		local def = item and Items.Defs[item.Item]
		if not item or not def or def.Slot ~= "Weapon" then
			return
		end
		local level = item.Upgrade or 0
		if level >= Upgrades.Max then
			return
		end
		local cost = Upgrades.Cost(item.Rarity, level + 1)
		if data.Gold < cost.Gold then
			notifyRemote:FireClient(player, "Not enough gold.")
			return
		end
		for _, need in cost.Materials do
			if InventoryService.CountOf(player, need.Item) < need.Count then
				notifyRemote:FireClient(player, `You need {need.Count} {Items.Defs[need.Item].DisplayName}.`)
				return
			end
		end
		ProgressService.AddGold(player, -cost.Gold)
		for _, need in cost.Materials do
			InventoryService.Take(player, need.Item, need.Count)
		end
		local worked = math.random() < cost.Chance
		if worked then
			item.Upgrade = level + 1
			InventoryService.RefreshTools(player)
		end
		InventoryService.PushInventory(player)
		upgradeResult:FireClient(player, { ItemId = itemId, Success = worked, Level = item.Upgrade or 0 })
	end)
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
