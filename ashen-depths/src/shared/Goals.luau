--!strict
-- The next big step for an adventurer, worked out from their save: shown on screen (client/common/GoalLine)
-- so a new player always knows where they're headed. A step is done once the player is past it (Checkpoint is
-- the floor after the last boss or hall they beat). Each text is two lines: what to do, then where.

local Config = require(script.Parent.Config)
local Floors = require(script.Parent.Floors)

local Goals = {}

type Step = { Text: string, Done: (data: any) -> boolean }

local function past(floor: number): (data: any) -> boolean
	return function(data)
		return (data.Checkpoint or 0) > floor
	end
end

local STEPS: { Step } = {
	{
		Text = "Relight the Wardstone\nFloor 1",
		Done = function(data)
			return (data.WardLit or 0) >= 1 or (data.DeepestFloor or 0) >= 2
		end,
	},
	{ Text = "Defeat the Gravekeeper\nFloor 5", Done = past(5) },
	{ Text = "Survive the Guardians' hall\nFloor 10", Done = past(10) },
	{ Text = "Defeat the Bone Warden\nFloor 15", Done = past(15) },
}
if Config.ChapterII then
	table.insert(STEPS, { Text = "Defeat the Rotgut Toad\nFloor 20", Done = past(20) })
	table.insert(STEPS, {
		Text = "Find the Ninth Patrol's captain\nFloor 25",
		Done = function(data)
			return data.MiraSaved == true or past(25)(data)
		end,
	})
	table.insert(STEPS, {
		Text = "Defeat Mother Spore\nFloor 30",
		Done = function(data)
			return data.MotherSlain == true or past(30)(data)
		end,
	})
end

-- The goal to show, or nil (a brand-new adventurer still in the intro).
function Goals.For(data: any): string?
	if data.IntroDone ~= true and (data.DeepestFloor or 0) == 0 then
		return nil
	end
	for _, step in STEPS do
		if not step.Done(data) then
			return step.Text
		end
	end
	local deepest = data.DeepestFloor or 0
	if deepest < Floors.HollowFirst then
		return `Enter The Hollow\nBelow floor {Floors.MaxFloor}`
	end
	return `How deep can you go?\nYour best: floor {deepest}`
end

return Goals
