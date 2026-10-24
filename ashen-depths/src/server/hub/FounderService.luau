--!strict
-- The Founders: the first FOUNDERS adventurers ever to come to Emberhold each get a number (#1, #2, ...) and the
-- Founder's Emberblade, a burning sword that is theirs forever (a keepsake: it can't be sold or dropped).
-- The count is one number in a DataStore, taken with UpdateAsync so two servers can never hand out the same
-- number or more than FOUNDERS in all. A player whose blade didn't fit in the bag gets it on a later visit.
-- Studio never takes a number (testing there must not use up the real ones).

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Common = script.Parent.Parent.Common
local DataService = require(Common.DataService)
local InventoryService = require(Common.InventoryService)
local BadgeAwards = require(Common.BadgeAwards)

local FounderService = {}

local FOUNDERS = 250
local BLADE = "FoundersBlade"

local closed = false -- this server has seen the count reach FOUNDERS: no more asking

-- Takes the next founder number, or nil when they're all gone (or the DataStore can't be reached now).
local function takeNumber(): (number?, number?)
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, "Founders")
	if not ok then
		return nil, nil
	end
	local taken: number? = nil
	local seen: number? = nil
	local success = pcall(function()
		store:UpdateAsync("Count", function(count: number?)
			taken = nil
			seen = count or 0
			if (count or 0) >= FOUNDERS then
				return nil -- all gone: change nothing
			end
			taken = (count or 0) + 1
			return taken
		end)
	end)
	if not success then
		return nil, nil
	end
	return taken, seen
end

local function giveBlade(player: Player, data: { [string]: any })
	if data.FounderGiven then
		return
	end
	if InventoryService.GiveItem(player, BLADE, "Epic", 1) > 0 then
		data.FounderGiven = true
	end
end

function FounderService.Start()
	local notifyRemote = Remotes.Event("Notify")
	DataService.OnLoaded(function(player, data)
		if data.FounderNumber then
			player:SetAttribute("Founder", data.FounderNumber)
			BadgeAwards.Give(player, "Founder")
			giveBlade(player, data)
			return
		end
		if closed or RunService:IsStudio() then
			return
		end
		local number, before = takeNumber()
		if number then
			data.FounderNumber = number
			player:SetAttribute("Founder", number)
			BadgeAwards.Give(player, "Founder")
			giveBlade(player, data)
			DataService.SaveNow(player)
			task.delay(3, function()
				notifyRemote:FireClient(player, `You are Founder #{number} of Emberwell! The Founder's Emberblade is yours, forever. ({FOUNDERS - number} blades left)`)
			end)
		elseif before and before >= FOUNDERS then
			closed = true
		end
	end)
end

return FounderService
