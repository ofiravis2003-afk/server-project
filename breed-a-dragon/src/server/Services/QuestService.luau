--!strict
-- The tutorial quest chain (see shared/Quests): one quest at a time, each with a reward.
-- Other services report what the player did through QuestService.Record, e.g. EggService
-- calls Record(player, "Hatch") after every hatch. Only the current quest's Kind counts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)

export type QuestState = { Step: number, Progress: number, SawIntro: boolean? }

local QuestService = {}

local questRemote = Remotes.Event("QuestUpdated")
local dialogRemote = Remotes.Event("ShowDialog")
local notifyRemote = Remotes.Event("Notify")

local function getState(data: { [string]: any }): QuestState
	local state = data.Quests
	if type(state) ~= "table" then
		state = {}
		data.Quests = state
	end
	if type(state.Step) ~= "number" then
		state.Step = 1
	end
	if type(state.Progress) ~= "number" then
		state.Progress = 0
	end
	return state
end

local function send(player: Player, state: QuestState)
	questRemote:FireClient(player, { Step = state.Step, Progress = state.Progress })
end

-- The player did `kind` `amount` times (default 1). Moves the current quest forward,
-- and pays its reward and starts the next one when it's done.
function QuestService.Record(player: Player, kind: string, amount: number?)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local state = getState(data)
	local quest = Quests.Get(state.Step)
	if not quest or quest.Kind ~= kind then
		return
	end

	state.Progress = math.min(state.Progress + (amount or 1), quest.Count)
	if state.Progress >= quest.Count then
		state.Step += 1
		state.Progress = 0
		CurrencyService.Add(player, quest.Reward)
		local nextQuest = Quests.Get(state.Step)
		local message = `✅ Quest complete: {quest.Text}! +{quest.Reward} {Config.Currency.Icon}`
		if not nextQuest then
			message ..= " All quests done, you're a true Keeper!"
		end
		notifyRemote:FireClient(player, message)
	end
	send(player, state)
end

-- What Elder Ember says when the player talks to him. Talking to him also counts for the
-- "TalkElder" quest; he then explains the quest that comes next.
function QuestService.TalkToElder(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local state = getState(data)
	local quest = Quests.Get(state.Step)
	local lines: { string }
	if quest and quest.Kind == "TalkElder" then
		lines = quest.Elder
		QuestService.Record(player, "TalkElder")
	elseif quest then
		lines = quest.Elder
	else
		lines = Quests.DoneElder
	end
	dialogRemote:FireClient(player, lines)
end

function QuestService.Start()
	DataService.OnLoaded(function(player, data)
		local state = getState(data)
		send(player, state)
		if not state.SawIntro then
			state.SawIntro = true
			dialogRemote:FireClient(player, Quests.Intro)
		end
	end)
end

return QuestService
