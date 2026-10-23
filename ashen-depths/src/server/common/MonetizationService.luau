--!strict
-- Robux purchases (ids in shared/Config):
--   Passes, bought once: Bigger Bag (BagSize attribute: twice the places), VIP (attribute VIP: +20% gold and XP
--   from kills in EnemyService, a VIP tag), Potion Belt (PotionBonus attribute: +2 of each potion). Checked when
--   the player arrives and the moment one is bought.
--   Products, bought again and again: gold (straight into the purse), and Revive (handled by whoever registers
--   it with OnProduct: the Depths puts the player back where they fell).
-- Every product purchase is given exactly once: its receipt id is kept in the save (data.Receipts) and the save
-- is written before Roblox is told it went through; if the save fails, the gold is taken back and Roblox
-- tries again later.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressService = require(script.Parent.ProgressService)

local MonetizationService = {}

local KEEP_RECEIPTS = 50 -- the last this-many receipt ids are remembered

local handlers: { [string]: (Player) -> boolean } = {}

-- Registers what a product does in this place (e.g. "Revive"); returns true when it was given.
function MonetizationService.OnProduct(name: string, handler: (Player) -> boolean)
	handlers[name] = handler
end

local function applyPass(player: Player, name: string)
	if name == "BiggerBag" then
		player:SetAttribute("BagSize", Config.BagSize * 2)
		InventoryService.PushInventory(player)
	elseif name == "VIP" then
		player:SetAttribute("VIP", true)
	elseif name == "PotionBelt" then
		player:SetAttribute("PotionBonus", 2)
	end
end

local function checkPasses(player: Player)
	for name, id in Config.Passes do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok and owns then
			applyPass(player, name)
		end
	end
end

local function productNamed(id: number): (string?, any)
	for name, product in Config.Products do
		if product.Id == id then
			return name, product
		end
	end
	return nil, nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.GetData(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (they left: Roblox tries again next time)
	end
	data.Receipts = data.Receipts or {}
	if table.find(data.Receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- given before
	end
	local name, product = productNamed(receipt.ProductId)
	if not name then
		warn(`[MonetizationService] Unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local notify = Remotes.Event("Notify")
	local gold = 0
	if product.Gold then
		gold = product.Gold
		ProgressService.AddGold(player, gold)
		notify:FireClient(player, `+{gold} gold. Thank you for supporting Emberwell!`)
	else
		local handler = handlers[name]
		if not (handler and handler(player)) then
			-- (it couldn't be used here: something for the money instead)
			InventoryService.GiveItem(player, "HealthPotion", "Common", 2)
			notify:FireClient(player, "That couldn't be used right now, so here are 2 Health Potions instead.")
		end
	end
	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > KEEP_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	if not DataService.SaveNow(player) then
		-- not stored: undo, so the next try doesn't give it twice
		table.remove(data.Receipts, table.find(data.Receipts, receipt.PurchaseId) :: number)
		if gold > 0 then
			ProgressService.AddGold(player, -gold)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start()
	DataService.OnLoaded(function(player, _data)
		checkPasses(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		if not bought then
			return
		end
		for name, id in Config.Passes do
			if id == passId then
				applyPass(player, name)
				Remotes.Event("Notify"):FireClient(player, "Thank you! Your pass is active.")
			end
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
