--!strict
-- Timed events (UTC): while one is on, monsters pay more gold, the town's news board names it, and players hear of
-- it when they arrive. Each also has its page on the game's page (Creator Hub > Engagement > Events), made by hand.

local Events = {}

export type Event = { Name: string, Text: string, Starts: number, Ends: number, Gold: number }

Events.List = {
	{
		Name = "Chapter II Weekend",
		Text = "Chapter II Weekend: monsters drop double gold until Monday!",
		Starts = DateTime.fromUniversalTime(2026, 11, 6).UnixTimestamp,
		Ends = DateTime.fromUniversalTime(2026, 11, 9).UnixTimestamp,
		Gold = 2,
	},
} :: { Event }

-- The event on now, if any.
function Events.Current(): Event?
	local now = os.time()
	for _, event in Events.List do
		if now >= event.Starts and now < event.Ends then
			return event
		end
	end
	return nil
end

-- How many times the usual gold a kill pays now.
function Events.GoldMultiplier(): number
	local event = Events.Current()
	return if event then event.Gold else 1
end

return Events
