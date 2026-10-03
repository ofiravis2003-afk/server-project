--!strict
-- Pays every player the Embers their active dragons make, once a second.
-- When a player comes back, they also get what their dragons made while they were away
-- (at Config.Income.OfflineRate, for up to Config.Income.OfflineMaxHours).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local DragonService = require(script.Parent.DragonService)

local TICK_SECONDS = 1
local MIN_AWAY_SECONDS = 60 -- don't bother with "welcome back" for a quick rejoin

local IncomeService = {}

local notifyRemote = Remotes.Event("Notify")

local function formatDuration(seconds: number): string
	local hours, minutes = seconds // 3600, (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

local function payOffline(player: Player, data: { [string]: any })
	local income = DragonService.GetIncome(player)
	if data.LastSeen > 0 and income > 0 then
		local away = math.min(os.time() - data.LastSeen, Config.Income.OfflineMaxHours * 3600)
		if away >= MIN_AWAY_SECONDS then
			local earned = math.floor(income * away * Config.Income.OfflineRate)
			if earned > 0 then
				CurrencyService.Add(player, earned)
				local amount = `{Config.Currency.Icon} {NumberFormat.Abbreviate(earned)}`
				notifyRemote:FireClient(
					player,
					`Welcome back! Your dragons made {amount} while you were away ({formatDuration(away)}).`
				)
			end
		end
	end
	data.LastSeen = os.time()
end

function IncomeService.Start()
	DataService.OnLoaded(payOffline)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.GetData(player)
				if data then
					local income = DragonService.GetIncome(player)
					if income > 0 then
						CurrencyService.Add(player, income * TICK_SECONDS)
					end
					data.LastSeen = os.time()
				end
			end
		end
	end)
end

return IncomeService
