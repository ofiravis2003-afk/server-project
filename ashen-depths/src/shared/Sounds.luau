--!strict
-- Every sound and piece of music in the game, in one place (free audio from the Roblox Creator Store), so any
-- of them can be swapped by changing its id here.

return {
	Music = {
		Town = { Id = "rbxassetid://99301366639600", Volume = 0.3 }, -- "Royal Courtyard"
		Depths = { Id = "rbxassetid://79559833217506", Volume = 0.3 }, -- "burial"
		Boss = { Id = "rbxassetid://80766740746561", Volume = 0.4 }, -- "Rise of Vaurinox"
		Caverns = { Id = "rbxassetid://96727522170625", Volume = 0.3 }, -- "strange hallway": the Rotwood Caverns
		CavernsBoss = { Id = "rbxassetid://1848159364", Volume = 0.4 }, -- "Darkness On The Edge Of Time D"
	},
	Effects = {
		Swing = { Id = "rbxassetid://5789211405", Volume = 0.5 }, -- a blade cutting the air
		Spell = { Id = "rbxassetid://139384716554132", Volume = 0.5 }, -- staff and tome casts
		Hit = { Id = "rbxassetid://9113542694", Volume = 0.6 }, -- a blow landing on bone
		Hurt = { Id = "rbxassetid://9120417632", Volume = 0.5 }, -- the player taking a hit
		EnemyDeath = { Id = "rbxassetid://9113544221", Volume = 0.7 }, -- bones collapsing
		Gold = { Id = "rbxassetid://5314631765", Volume = 0.5 }, -- coins
		Chest = { Id = "rbxassetid://9116169548", Volume = 0.6 }, -- a key turning, a lid opening
		Potion = { Id = "rbxassetid://9114171955", Volume = 0.6 }, -- a gulp
		GateSlam = { Id = "rbxassetid://9116700296", Volume = 0.7 }, -- a room's iron gates slamming shut
		BossRoar = { Id = "rbxassetid://116597157482674", Volume = 0.8 },
		LevelUp = { Id = "rbxassetid://96659579913194", Volume = 0.6 },
		Caw = { Id = "rbxassetid://5829815715", Volume = 0.25 }, -- a bird calling over the town, now and then
	},
	-- Under the music, all the time: the town's birdsong.
	Ambience = {
		Town = { Id = "rbxassetid://9112832288", Volume = 0.35 }, -- "Mountain Birds 1"
	},
}
