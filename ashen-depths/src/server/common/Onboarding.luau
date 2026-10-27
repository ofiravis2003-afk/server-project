--!strict
-- A new adventurer's first steps, counted for Roblox's onboarding funnel (Creator Hub > Analytics > Funnels):
-- how many new players get to each step, so it shows where they give up. Roblox keeps each step once per
-- player. Only players who haven't yet been past floor 1 are counted (the funnel is about newcomers).

local AnalyticsService = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)

local STEPS: { [string]: number } = {
	Joined = 1, -- a new player's first visit (the intro starts)
	IntroWatched = 2, -- the fly-over over Emberhold ended (or was skipped)
	TookBrand = 3, -- took the Guild Brand from Aldric
	Descended = 4, -- pressed Descend at the Great Well
	ReachedDepths = 5, -- arrived on floor 1 of the Depths
	FirstFight = 6, -- the gates of a first room slammed behind them
	FirstRoomCleared = 7, -- cleared it
	ReachedFloor2 = 8, -- went down the stairs to floor 2
}

local Onboarding = {}

function Onboarding.Step(player: Player, name: string)
	local step = STEPS[name]
	local data = DataService.GetData(player)
	if not step or not data or (data.DeepestFloor or 0) >= 2 then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

return Onboarding
