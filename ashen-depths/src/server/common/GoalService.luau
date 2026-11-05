--!strict
-- Keeps each player's next goal (shared/Goals) in their "Goal" attribute, for the line on screen
-- (client/common/GoalLine). Checked every few seconds: the save changes in many places (bosses, halls,
-- Wardstones), and setting an attribute to the value it already has costs nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Goals = require(ReplicatedStorage.Shared.Goals)
local DataService = require(script.Parent.DataService)

local GoalService = {}

local EVERY = 2 -- seconds

local function refresh(player: Player)
	local data = DataService.GetData(player)
	player:SetAttribute("Goal", if data then Goals.For(data) else nil)
end

function GoalService.Start()
	DataService.OnLoaded(function(player, _data)
		refresh(player)
	end)
	task.spawn(function()
		while true do
			task.wait(EVERY)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return GoalService
