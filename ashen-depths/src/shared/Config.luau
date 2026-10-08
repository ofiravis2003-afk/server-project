--!strict
-- Game-wide settings shared by both places (Emberhold and Depths).

return {
	-- Bump this on any change: both places print it on start, so you can see they run the same code.
	Version = "0.1.0",

	-- Place ids, filled in after the places are created on the Roblox website (step 0.1).
	PlaceIds = {
		Emberhold = 127167308890339,
		Depths = 94536878288268,
	},

	MaxPartySize = 4,

	-- While building: every player gets one weapon of each type, and enemies come back after dying.
	-- Turn off before launch.
	TestMode = true,
}
