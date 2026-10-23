--!strict
-- Friends who bring friends: a player who joins Emberwell for the first time from someone's game invite gets a
-- welcome purse, and the one who invited them (if they're in the same town) gets a finder's reward, once per
-- friend and up to MAX_REWARDED friends. (The invite itself: the "Invite friends" button in the Party window.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local ProgressService = require(Common.ProgressService)

local ReferralService = {}

local WELCOME_GOLD = 100
local FINDER_GOLD = 250
local MAX_REWARDED = 20

function ReferralService.Start()
	local notifyRemote = Remotes.Event("Notify")
	DataService.OnLoaded(function(player, data)
		if (data.JoinCount or 0) ~= 1 then
			return -- (only a brand-new adventurer counts)
		end
		local ok, join = pcall(function()
			return player:GetJoinData()
		end)
		local by = ok and type(join) == "table" and tonumber(join.ReferredByPlayerId) or nil
		if not by or by == player.UserId then
			return
		end
		ProgressService.AddGold(player, WELCOME_GOLD)
		notifyRemote:FireClient(player, `A friend brought you to Emberhold! Here's {WELCOME_GOLD} gold to start.`)
		local inviter = Players:GetPlayerByUserId(by)
		local theirs = inviter and DataService.GetData(inviter)
		if inviter and theirs then
			theirs.Referrals = theirs.Referrals or {}
			local key = tostring(player.UserId)
			local count = 0
			for _ in theirs.Referrals do
				count += 1
			end
			if not theirs.Referrals[key] and count < MAX_REWARDED then
				theirs.Referrals[key] = true
				ProgressService.AddGold(inviter, FINDER_GOLD)
				notifyRemote:FireClient(inviter, `{player.DisplayName} came because of you! +{FINDER_GOLD} gold.`)
			end
		end
	end)
end

return ReferralService
