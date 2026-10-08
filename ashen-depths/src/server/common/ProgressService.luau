--!strict
-- Character level, XP and gold. Also sets the player's max health from their level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leveling = require(ReplicatedStorage.Shared.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local statsRemote = Remotes.Event("StatsUpdated")
local notifyRemote = Remotes.Event("Notify")

local ProgressService = {}

function ProgressService.PushStats(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	statsRemote:FireClient(player, {
		Level = data.Level,
		XP = data.XP,
		XPToNext = Leveling.XPToNext(data.Level),
		Gold = data.Gold,
		MaxLevel = Leveling.MaxLevel,
	})
end

-- Sets max health from the level, and heals to full.
local function applyHealth(player: Player)
	local data = DataService.GetData(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	humanoid.MaxHealth = Leveling.MaxHealth(data.Level)
	humanoid.Health = humanoid.MaxHealth
end

function ProgressService.AddGold(player: Player, amount: number)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	data.Gold += amount
	ProgressService.PushStats(player)
end

function ProgressService.AddXP(player: Player, amount: number)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	data.XP += amount
	local leveledUp = false
	while data.Level < Leveling.MaxLevel and data.XP >= Leveling.XPToNext(data.Level) do
		data.XP -= Leveling.XPToNext(data.Level)
		data.Level += 1
		leveledUp = true
	end
	if data.Level >= Leveling.MaxLevel then
		data.XP = 0
	end
	if leveledUp then
		applyHealth(player)
		notifyRemote:FireClient(player, `Level up! You are now level {data.Level}.`)
	end
	ProgressService.PushStats(player)
end

function ProgressService.Start()
	DataService.OnLoaded(function(player, _data)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			applyHealth(player)
		end)
		applyHealth(player)
		ProgressService.PushStats(player)
	end)
end

return ProgressService
