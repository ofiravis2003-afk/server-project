--!strict
-- Quest progress, in both places. Kills and floors reached count in the Depths; quests are taken and turned
-- in at the Guild in Emberhold (Aldric or the quest board), or with the townsperson who gave them (Old Pip).
-- Saved in data.Quests[id] = { Progress, State } where State is "Active" or "Done"; data.RankPoints adds up
-- to the Guild rank (data.GuildRank).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressService = require(script.Parent.ProgressService)
local RateLimiter = require(script.Parent.RateLimiter)

local QuestService = {}

local updatedRemote = Remotes.Event("QuestsUpdated")
local notifyRemote = Remotes.Event("Notify")
local actionLimiter = RateLimiter.new(0.3)

-- How far along a quest is right now (Collect counts what's in the bag).
local function progressOf(player: Player, data: { [string]: any }, quest: Quests.Quest): number
	if quest.Kind == "Collect" then
		return math.min(InventoryService.CountOf(player, quest.Target :: string), quest.Count)
	end
	local saved = data.Quests[quest.Id]
	return if saved then math.min(saved.Progress or 0, quest.Count) else 0
end

function QuestService.Push(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local list = {}
	for _, quest in Quests.List do
		local saved = data.Quests[quest.Id]
		local state = if saved then saved.State else nil
		if state == "Done" and quest.Repeatable then
			state = "Open" -- a bounty, ready to take again
		end
		if not state and quest.Needs and not (data.Quests[quest.Needs] and data.Quests[quest.Needs].State == "Done") then
			state = "Locked"
		end
		table.insert(list, { Id = quest.Id, State = state or "Open", Progress = progressOf(player, data, quest) })
	end
	updatedRemote:FireClient(player, { Quests = list, Points = data.RankPoints or 0 })
end

local function setRank(player: Player, data: { [string]: any })
	local standing = Quests.Standing(data.RankPoints or 0)
	if standing.Label ~= data.GuildRank then
		local wasRank = data.GuildRank and string.split(data.GuildRank, " ")[1]
		data.GuildRank = standing.Label
		if wasRank and wasRank ~= standing.Rank then
			notifyRemote:FireClient(player, `The Guild raises you to {standing.Rank} rank! ({standing.Label})`)
		else
			notifyRemote:FireClient(player, `Guild rank up: {standing.Label}`)
		end
	end
	player:SetAttribute("GuildRank", standing.Label)
end

local function advance(player: Player, kind: string, target: string?, amount: number, absolute: boolean)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local changed = false
	for _, quest in Quests.List do
		local saved = data.Quests[quest.Id]
		if saved and saved.State == "Active" and quest.Kind == kind and (quest.Target == nil or quest.Target == target) then
			local before = saved.Progress or 0
			saved.Progress = math.min(if absolute then math.max(before, amount) else before + amount, quest.Count)
			if saved.Progress ~= before then
				changed = true
				if saved.Progress >= quest.Count and before < quest.Count then
					notifyRemote:FireClient(player, `Quest complete: {quest.Title}. Report to Aldric in Emberhold.`)
				end
			end
		end
	end
	if changed then
		QuestService.Push(player)
	end
end

-- A player helped kill `enemyName`.
function QuestService.OnKill(player: Player, enemyName: string)
	advance(player, "Kill", enemyName, 1, false)
end

-- A player arrived on floor `floor`.
function QuestService.OnReachFloor(player: Player, floor: number)
	advance(player, "Reach", nil, floor, true)
end

local function onAction(player: Player, action: any, id: any)
	if not actionLimiter:Check(player) or type(id) ~= "string" then
		return
	end
	local quest = Quests.ById[id]
	local data = DataService.GetData(player)
	if not quest or not data or player:GetAttribute("QuestGiver") ~= Quests.GiverOf(quest) then
		return
	end
	local saved = data.Quests[id]
	if action == "Accept" then
		if saved and not (saved.State == "Done" and quest.Repeatable) then
			return
		end
		if quest.Needs and not (data.Quests[quest.Needs] and data.Quests[quest.Needs].State == "Done") then
			return
		end
		local active = 0
		for _, s in data.Quests do
			if s.State == "Active" then
				active += 1
			end
		end
		if active >= Quests.MaxActive then
			notifyRemote:FireClient(player, `You can carry only {Quests.MaxActive} quests at once.`)
			return
		end
		-- a Reach quest already done counts at once
		data.Quests[id] = { Progress = if quest.Kind == "Reach" then math.min(data.DeepestFloor or 0, quest.Count) else 0, State = "Active" }
	elseif action == "TurnIn" then
		if not saved or saved.State ~= "Active" or progressOf(player, data, quest) < quest.Count then
			return
		end
		if quest.Kind == "Collect" and not InventoryService.Take(player, quest.Target :: string, quest.Count) then
			return
		end
		saved.State = "Done"
		ProgressService.AddGold(player, quest.Gold)
		ProgressService.AddXP(player, quest.XP)
		data.RankPoints = (data.RankPoints or 0) + quest.Points
		setRank(player, data)
		InventoryService.PushInventory(player)
		if quest.Thanks then
			notifyRemote:FireClient(player, quest.Thanks)
		end
		notifyRemote:FireClient(player, `{quest.Title} done: +{quest.Gold} gold, +{quest.XP} XP.`)
	elseif action == "Abandon" then
		if saved and saved.State == "Active" then
			data.Quests[id] = nil
		end
	else
		return
	end
	QuestService.Push(player)
end

-- Players talking to a quest giver (Aldric or the Guild board count as "Aldric") may take and turn in
-- that giver's quests. nil when they walk away.
function QuestService.SetGiver(player: Player, giver: string?)
	player:SetAttribute("QuestGiver", giver)
end

-- Whether the player still has to find a quest's item (it's taken, and not yet in the bag or handed over).
function QuestService.Wants(player: Player, questId: string): boolean
	local data = DataService.GetData(player)
	local quest = Quests.ById[questId]
	if not data or not quest then
		return false
	end
	local saved = data.Quests[questId]
	return not (saved and saved.State == "Done") and InventoryService.CountOf(player, quest.Target :: string) < quest.Count
end

function QuestService.Start()
	DataService.OnLoaded(function(player, data)
		if type(data.Quests) ~= "table" then
			data.Quests = {}
		end
		data.GuildRank = Quests.Standing(data.RankPoints or 0).Label -- quietly, no rank-up message on join
		setRank(player, data)
		QuestService.Push(player)
	end)
	Remotes.Event("QuestAction").OnServerEvent:Connect(onAction)
end

return QuestService
