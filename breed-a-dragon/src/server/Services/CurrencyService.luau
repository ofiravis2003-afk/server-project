--!strict
-- Owns the Embers balance. Every system that gives or takes Embers goes through here,
-- so the saved value and the leaderboard number never get out of sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local CurrencyService = {}

local function isValidAmount(amount: number): boolean
	return type(amount) == "number" and amount > 0 and amount == amount and amount ~= math.huge
end

local function updateLeaderstat(player: Player, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(Config.Currency.Name)
	if stat and stat:IsA("NumberValue") then
		stat.Value = value
	end
end

function CurrencyService.Get(player: Player): number
	local data = DataService.GetData(player)
	return if data then data.Embers else 0
end

function CurrencyService.Add(player: Player, amount: number)
	local data = DataService.GetData(player)
	if not data or not isValidAmount(amount) then
		return
	end
	data.Embers += amount
	data.TotalEmbersEarned += amount
	updateLeaderstat(player, data.Embers)
end

-- Takes `amount` Embers if the player can afford it. Returns whether it worked.
function CurrencyService.Spend(player: Player, amount: number): boolean
	local data = DataService.GetData(player)
	if not data or not isValidAmount(amount) or data.Embers < amount then
		return false
	end
	data.Embers -= amount
	updateLeaderstat(player, data.Embers)
	return true
end

function CurrencyService.Start()
	DataService.OnLoaded(function(player, data)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"

		local embers = Instance.new("NumberValue")
		embers.Name = Config.Currency.Name
		embers.Value = data.Embers
		embers.Parent = leaderstats

		leaderstats.Parent = player
	end)
end

return CurrencyService
