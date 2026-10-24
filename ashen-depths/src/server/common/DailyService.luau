--!strict
-- The daily gift and the daily tasks (shared/Daily has the ladder and the task pool).
--   On arrival, the first visit of a day gives that day's gift (data.DailyStreak climbs, or starts over after a
--   missed day) and deals out that day's three tasks (data.DailyTasks).
--   Progress comes in from the game (OnKill, OnChest, OnFloor); a task pays out the moment it's done.
-- Every change is sent to the player ("DailyUpdated"); Gift is set only when the day's gift was just given,
-- so the screen shows it once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daily = require(ReplicatedStorage.Shared.Daily)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressService = require(script.Parent.ProgressService)

local DailyService = {}

local updatedRemote = Remotes.Event("DailyUpdated")
local notifyRemote = Remotes.Event("Notify")

local function push(player: Player, gift: number?)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	updatedRemote:FireClient(player, {
		Streak = data.DailyStreak or 0,
		Tasks = data.DailyTasks or {},
		Gift = gift,
	})
end

local function giveReward(player: Player, reward: Daily.Reward)
	if reward.Gold then
		ProgressService.AddGold(player, reward.Gold)
	end
	for _, entry in reward.Items or {} do
		InventoryService.GiveItem(player, entry.Item, "Common", entry.Count)
	end
	if reward.EpicArmor then
		local pieces = Items.ArmorPieces
		InventoryService.GiveItem(player, pieces[math.random(1, #pieces)], "Epic", 1)
	end
end

-- Three different tasks for this player today (the same three if asked again the same day).
local function dealTasks(player: Player, today: number): { { Id: string, Progress: number, Done: boolean } }
	local rng = Random.new(today * 7919 + player.UserId)
	local pool = table.clone(Daily.Tasks)
	local tasks = {}
	for _ = 1, math.min(Daily.TasksPerDay, #pool) do
		local pick = table.remove(pool, rng:NextInteger(1, #pool)) :: Daily.Task
		table.insert(tasks, { Id = pick.Id, Progress = 0, Done = false })
	end
	return tasks
end

local function newDay(player: Player, data: { [string]: any }): number?
	local today = Daily.Today()
	if data.DailyDay == today then
		return nil
	end
	local streak = if data.DailyDay == today - 1 then (data.DailyStreak or 0) + 1 else 1
	data.DailyDay = today
	data.DailyStreak = streak
	data.DailyTasks = dealTasks(player, today)
	local step = (streak - 1) % #Daily.Rewards + 1
	giveReward(player, Daily.Rewards[step])
	return step
end

local function advance(player: Player, kind: string, target: string?, amount: number)
	local data = DataService.GetData(player)
	if not data or data.DailyDay ~= Daily.Today() then
		return
	end
	local changed = false
	for _, saved in data.DailyTasks or {} do
		local task = Daily.ById[saved.Id]
		if task and not saved.Done and task.Kind == kind and (task.Target == nil or task.Target == target) then
			saved.Progress = math.min(saved.Progress + amount, task.Count)
			changed = true
			if saved.Progress >= task.Count then
				saved.Done = true
				ProgressService.AddGold(player, task.Gold)
				ProgressService.AddXP(player, task.XP)
				notifyRemote:FireClient(player, `Daily task done: {task.Text}! +{task.Gold} gold, +{task.XP} XP.`)
			end
		end
	end
	if changed then
		push(player)
	end
end

-- A monster this player helped kill (a boss counts for the boss task too).
function DailyService.OnKill(player: Player, enemyName: string)
	advance(player, "Kill", enemyName, 1)
	local def = Enemies[enemyName] :: any
	if def and def.Boss then
		advance(player, "Boss", nil, 1)
	end
end

function DailyService.OnChest(player: Player)
	advance(player, "Chest", nil, 1)
end

function DailyService.OnFloor(player: Player)
	advance(player, "Floor", nil, 1)
end

function DailyService.Start()
	DataService.OnLoaded(function(player, data)
		local gift = newDay(player, data)
		task.delay(if gift then 4 else 1, function() -- (after the opening screen)
			push(player, gift)
		end)
	end)
end

return DailyService
