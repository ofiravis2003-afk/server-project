--!strict
-- Every enemy type: its stats and its rewards.
--   Windup: seconds the enemy shows its attack coming before the hit lands (time to step away)
--   Model: which 3D model in ServerStorage.EnemyModels to build from (default: the enemy's own name)
--   Scale: size compared to that model (the little slimes are small slimes)
--   Animations: published animation ids for the enemy's own 3D model (ServerStorage.EnemyModels.<name>).
--               Any that are missing are skipped: no walk = it glides, no death = it just falls over.
--   AnimationSpeeds: play some clips faster (Tripo made the attack and death 5 seconds long).
--   AttackClips: several attack clips to pick from at random, each with HitAt = the second the blow lands in
--                the clip; it is sped up or slowed so that moment meets the end of the Windup.
--   EliteAttackClips: the elite's own attacks (a heavier blow).
--   CrumbleInto: on death the body flinches (its Hit clip) and after `At` seconds shatters: it vanishes in a
--                burst of dust, bones fly out and tumble across the floor, and this dungeon prop stays behind.
--                Its own death clip is skipped (Tripo's looked like a stumble), unless AfterDeathClip: then it
--                plays its death clip first and shatters `At` seconds in, FallBack studs from where it stood
--                (where the clip has laid the body; the server can't see the clip's bones once the body is still),
--                FallAngle degrees turned from the way it faces (default 180: straight behind).
--   Sink: studs to lower the body (at the model's own size), for clips that crouch below the standing pose
--         (the Mixamo clips lost their crouch when their hips were zeroed, so the feet hovered).
--   ModelYaw: degrees to turn the model's facing, when its animations face another way than its
--             standing pose (the Tripo skeleton's animations face backwards: 180).
--   Ranged: keeps its distance and shoots: backs off when a player is closer than KeepAway, shows a red
--           aiming line for `Windup` seconds, then fires an arrow that hits whoever is still within
--           HitRadius of where it was aimed. AttackRange is then the shooting range.
--   HeldProps: dungeon props held on bones (a sword in the hand, a shield on the forearm, the archer's bow).
--              A prop that carries its own "Grip" attachment (the Tripo weapons) is held by it as it is.
--              Otherwise GripAngles (degrees, X/Y/Z) turn it in the hand (the bow: upright, square to the arrow
--              at full draw), GripOffset moves it along the hand bone (which sits at the wrist) into the palm,
--              and Scale resizes it.
--   EliteHeldProps: what the elite version holds instead (a heavier weapon, so it stands out).
--   DeathStyle: "Splat" bursts into goo instead of falling over.
--   SplitInto: on death, this many of that enemy pop out where it died (slimes split in two).
--   Squishy: wobbles as it moves (drawn by the players' screens).
--   Procedural: "Scurry" = no animation clips; the body is moved by code (bouncing run, lunging bite).
--   Pack: comes in a group of this many (min, max) in one spawn.
--   Boss: a boss fight: its name on the big bar at the top of the screen, and its special moves on top of its
--         ordinary blows. Slam: leaps at a player; a red circle on the floor shows where it lands (HitAt seconds
--         into the clip) and everyone still inside is hit. Kick: shoves away whoever crowds it. Summon: at each
--         health fraction in At, it calls Count of Minion up out of the ground (RiseAt seconds into the clip).
--         Intro: the scene when the lair locks: the camera turns to the boss, it speaks its Lines, and its name
--         comes up with Subtitle. It doesn't fight until the scene is over.
--         Farewell: what it says as it falls, one line after another.

export type HeldProp = { Prop: string, Bone: string, GripAngles: { number }?, GripOffset: { number }?, Scale: number? }

export type BossDef = {
	Title: string,
	Slam: { Id: string, HitAt: number, Radius: number, Range: number, DamageScale: number, Cooldown: number },
	Kick: { Id: string, HitAt: number, Range: number, Push: number, DamageScale: number, Cooldown: number },
	Summon: {
		Id: string,
		At: { number },
		Minion: string,
		Count: number,
		RiseAt: number,
		Length: number,
		-- arrows falling from the dark: red circles round each player, then the hit
		Rain: { Count: number, Radius: number, Delay: number, DamageScale: number }?,
	},
	Intro: { Subtitle: string, Lines: { string }, Pose: string? }, -- Pose: the clip it plays as it speaks
	Farewell: { string }?,
	-- Below At of its health it roars (Id) and fights faster: moves SpeedScale quicker, attacks every
	-- CooldownScale as often, runs (Run) and lunges (Lunge, used in place of its Slam).
	Rage: {
		Id: string,
		At: number,
		Length: number,
		SpeedScale: number,
		CooldownScale: number,
		Run: string?,
		Lunge: { Id: string, HitAt: number, Radius: number, Range: number, DamageScale: number, Cooldown: number }?,
	}?,
}

export type EnemyDef = {
	DisplayName: string,
	Health: number,
	Damage: number,
	WalkSpeed: number,
	AggroRange: number,
	AttackRange: number,
	AttackCooldown: number,
	Windup: number,
	XP: number,
	Gold: { number },
	-- What it leaves behind for each player who hurt it: Count of Item with this Chance (elites always drop,
	-- and twice as many). Boss drops are certain.
	Drops: { { Item: string, Chance: number, Count: { number }? } }?,
	RespawnTime: number,
	Model: string?,
	Scale: number?,
	Animations: { Idle: string?, Walk: string?, Attack: string?, Hit: string?, Death: string? }?,
	AnimationSpeeds: { [string]: number }?,
	AttackClips: { { Id: string, HitAt: number } }?,
	EliteAttackClips: { { Id: string, HitAt: number } }?,
	ModelYaw: number?,
	Sink: number?,
	CrumbleInto: { Prop: string, At: number, AfterDeathClip: boolean?, FallBack: number?, FallAngle: number? }?,
	Ranged: { KeepAway: number, ProjectileSpeed: number, HitRadius: number }?,
	HeldProps: { HeldProp }?,
	EliteHeldProps: { HeldProp }?,
	DeathStyle: string?,
	SplitInto: { Name: string, Count: number }?,
	Squishy: boolean?,
	Procedural: string?,
	Pack: { number }?,
	Boss: BossDef?,
	-- Chapter II (the Rotwood Caverns): grown over with the green ember's mushrooms, trailing spores.
	Infected: boolean?,
	Blight: number?, -- Blight stacks its blows add (BlightService)
	BurstSpores: { Radius: number, Blight: number, DamageScale: number }?, -- bursts into a spore cloud as it dies
}

-- The skeleton re-rigged in Mixamo (SkeletonMixamo), with clips from Mixamo's Sword and Shield pack.
-- Each attack's HitAt is when its blade moves fastest (measured on the rig).
local SWORD_ANIMATIONS = {
	Idle = "rbxassetid://130119968374996",
	Walk = "rbxassetid://126296910233652", -- a run, slowed to its walking pace
	Hit = "rbxassetid://79389710080744", -- the archer's flinch: same rig
	Death = "rbxassetid://125607566576486",
}
local SWORD_ATTACKS = {
	{ Id = "rbxassetid://134558356329215", HitAt = 0.63 },
	{ Id = "rbxassetid://136004950014332", HitAt = 0.77 },
	{ Id = "rbxassetid://92859713701069", HitAt = 0.43 },
}
local ELITE_SWORD_ATTACKS = {
	{ Id = "rbxassetid://95035207085273", HitAt = 1.17 }, -- leaps up and brings the axe down
}

-- The skeleton re-rigged in Mixamo (SkeletonMixamo), with clips from Mixamo's Longbow pack.
local ARCHER_ANIMATIONS = {
	Idle = "rbxassetid://101802276597443",
	Walk = "rbxassetid://118727143513732",
	Attack = "rbxassetid://99143341242529", -- Standing Draw Arrow, about 1 second
	Hit = "rbxassetid://79389710080744",
	Death = "rbxassetid://114717097858899",
}

-- The Gravekeeper (floor 5): Tripo model rigged in Mixamo, clips from Mixamo's Great Sword pack.
local GRAVEKEEPER_ANIMATIONS = {
	Idle = "rbxassetid://105381899996213",
	Walk = "rbxassetid://99372373898155",
	Death = "rbxassetid://71892949823815",
	-- (no Hit clip: a boss doesn't flinch at every blow)
}

local BONE_WARDEN_ANIMATIONS = {
	Idle = "rbxassetid://121480404020873",
	Walk = "rbxassetid://111168615059154",
	Death = "rbxassetid://114386714081090",
}

local Enemies: { [string]: EnemyDef } = {
	-- The boss of chapter I (floor 15): the last knight of Valdren, keeping the sealed gate to the king.
	-- Phase 1: wide sword blows, a spinning shove when crowded, a leap onto the far ones.
	-- Phase 2 (70% and 45%): raises his sword and calls archers up from the dead, while arrows rain down.
	-- Phase 3 (under 30%): roars, then runs and lunges, twice as fast.
	BoneWarden = {
		DisplayName = "The Bone Warden",
		Model = "BoneWarden",
		Health = 6500,
		Damage = 42,
		WalkSpeed = 11,
		AggroRange = 100,
		AttackRange = 11,
		AttackCooldown = 2.2,
		Windup = 0.6,
		XP = 1200,
		Gold = { 600, 900 },
		Drops = { { Item = "GraveShroud", Chance = 1, Count = { 3, 5 } }, { Item = "Bone", Chance = 1, Count = { 10, 15 } } },
		RespawnTime = 5,
		Animations = BONE_WARDEN_ANIMATIONS,
		AnimationSpeeds = { Walk = 0.9 },
		Sink = 0.5, -- measured: the idle stance lifts the feet only a little
		AttackClips = { { Id = "rbxassetid://80380547311498", HitAt = 0.6 } },
		HeldProps = { { Prop = "WardenSword", Bone = "mixamorig:RightHand" } },
		Boss = {
			Title = "The Bone Warden",
			Slam = { Id = "rbxassetid://123467229735275", HitAt = 1.2, Radius = 12, Range = 36, DamageScale = 1.7, Cooldown = 9 },
			Kick = { Id = "rbxassetid://140137057401616", HitAt = 0.85, Range = 9, Push = 55, DamageScale = 0.9, Cooldown = 6 },
			Summon = {
				Id = "rbxassetid://109645801773793",
				At = { 0.7, 0.45 },
				Minion = "SkeletonArcher",
				Count = 2,
				RiseAt = 2,
				Length = 4.6,
				Rain = { Count = 3, Radius = 6, Delay = 1.4, DamageScale = 0.8 },
			},
			Intro = {
				Subtitle = "Last Knight of Valdren",
				Pose = "rbxassetid://116384144343895",
				Lines = {
					"So the Gravekeeper's shovel finally broke.",
					"A thousand years ago I swore an oath to King Malachar: none shall pass this gate. Not the living. Not the dead.",
					"Your Guild sends children to die at my feet, year after year. Come, child. Let us keep the tradition.",
				},
			},
			Farewell = {
				"...There is a name. Carved over my heart. Read it to me.",
				"Hadric. Ser Hadric. Yes... I remember now.",
				"Beware, child. The King does not sleep. And beneath my gate... something else is waking.",
			},
			Rage = {
				Id = "rbxassetid://125215761877496",
				At = 0.3,
				Length = 3.2,
				SpeedScale = 1.6,
				CooldownScale = 0.55,
				Run = "rbxassetid://132904689104673",
				Lunge = { Id = "rbxassetid://132291220982206", HitAt = 0.9, Radius = 9, Range = 30, DamageScale = 1.4, Cooldown = 6 },
			},
		},
	},
	Gravekeeper = {
		DisplayName = "The Gravekeeper",
		Model = "Gravekeeper",
		Health = 1500,
		Damage = 24,
		WalkSpeed = 10,
		AggroRange = 90,
		AttackRange = 9,
		AttackCooldown = 2.4,
		Windup = 0.6,
		XP = 250,
		Gold = { 150, 250 },
		Drops = { { Item = "GraveShroud", Chance = 1 }, { Item = "Bone", Chance = 1, Count = { 4, 7 } } },
		RespawnTime = 5,
		Animations = GRAVEKEEPER_ANIMATIONS,
		AnimationSpeeds = { Walk = 0.8 },
		Sink = 1.7, -- its two-handed stance crouches below the rest pose
		AttackClips = { { Id = "rbxassetid://90230781354308", HitAt = 0.57 } },
		HeldProps = { { Prop = "GravekeeperShovel", Bone = "mixamorig:RightHand" } },
		Boss = {
			Title = "The Gravekeeper",
			Slam = { Id = "rbxassetid://92398419997787", HitAt = 1.2, Radius = 11, Range = 34, DamageScale = 1.8, Cooldown = 9 },
			Kick = { Id = "rbxassetid://136966551268009", HitAt = 0.53, Range = 6, Push = 50, DamageScale = 0.7, Cooldown = 5 },
			Summon = { Id = "rbxassetid://83831588165460", At = { 0.66, 0.33 }, Minion = "Skeleton", Count = 3, RiseAt = 1.6, Length = 3.5 },
			Intro = {
				Subtitle = "Keeper of the Drowned Dead",
				Lines = {
					"Another one... crawling down from Emberhold with a torch and a guild badge.",
					"I buried the people of Valdren when the mountain fell. I have buried every fool since.",
					"The King sleeps below. Nobody wakes him. Lie down, little hero... the earth is soft here.",
				},
			},
			Farewell = {
				"So cold... I kept them company so long.",
				"Bury me with them, little hero. And mind the knight at the gate. He still remembers his oath.",
			},
		},
	},
	Skeleton = {
		DisplayName = "Skeleton",
		Model = "SkeletonMixamo",
		Health = 85,
		Damage = 11,
		WalkSpeed = 11,
		AggroRange = 45,
		AttackRange = 4.5,
		AttackCooldown = 1.25,
		Windup = 0.7, -- the attack clip raises its arm before the swing; this is the time to step away
		XP = 12,
		Gold = { 3, 6 },
		Drops = { { Item = "Bone", Chance = 0.6 } },
		RespawnTime = 5,
		Animations = SWORD_ANIMATIONS,
		AnimationSpeeds = { Walk = 0.8 },
		AttackClips = SWORD_ATTACKS,
		EliteAttackClips = ELITE_SWORD_ATTACKS,
		-- Turned so its head and chest face the player (measured in play).
		ModelYaw = -7,
		Scale = 1.3, -- crouched in its guard it stood shorter than a player
		Sink = 0.8,
		-- On the ground by 1.6s; it falls back from its guard stance, which stands side-on to its blows.
		CrumbleInto = { Prop = "BonePile", At = 1.7, AfterDeathClip = true, FallBack = 3.7, FallAngle = 229 },
		HeldProps = {
			{ Prop = "RustySword", Bone = "mixamorig:RightHand" },
			{ Prop = "RoundShield", Bone = "mixamorig:LeftForeArm" },
		},
		EliteHeldProps = {
			{ Prop = "WarAxe", Bone = "mixamorig:RightHand" },
			{ Prop = "RoundShield", Bone = "mixamorig:LeftForeArm" },
		},
	},
	SkeletonArcher = {
		DisplayName = "Skeleton Archer",
		Model = "SkeletonMixamo",
		Health = 60,
		Damage = 10,
		WalkSpeed = 10,
		AggroRange = 60,
		AttackRange = 34,
		AttackCooldown = 2.4,
		Windup = 0.9,
		XP = 14,
		Gold = { 4, 7 },
		Drops = { { Item = "Fletching", Chance = 0.5 }, { Item = "Bone", Chance = 0.3 } },
		RespawnTime = 5,
		Animations = ARCHER_ANIMATIONS,
		-- Its clips stand side-on with the bow arm out; this turns the body so the arrow flies at the player.
		ModelYaw = 81,
		Scale = 1.3,
		Sink = 0.42,
		CrumbleInto = { Prop = "BonePile", At = 1.6, AfterDeathClip = true, FallBack = 4.4 },
		Ranged = { KeepAway = 12, ProjectileSpeed = 80, HitRadius = 3 },
		HeldProps = {
			{
				Prop = "Bow",
				Bone = "mixamorig:LeftHand",
				GripAngles = { -125.7, 41.3, -118.5 },
				GripOffset = { 0, 0.3, 0 },
				Scale = 0.85,
			},
		},
	},
	Slime = {
		DisplayName = "Slime",
		Health = 75,
		Damage = 10,
		WalkSpeed = 7,
		AggroRange = 40,
		AttackRange = 4,
		AttackCooldown = 1.6,
		Windup = 0.5,
		XP = 10,
		Gold = { 2, 5 },
		Drops = { { Item = "SlimeGel", Chance = 0.6 } },
		RespawnTime = 5,
		DeathStyle = "Splat",
		SplitInto = { Name = "SlimeSmall", Count = 2 },
		Squishy = true,
	},
	Rat = {
		DisplayName = "Giant Rat",
		Health = 38,
		Damage = 7,
		WalkSpeed = 19,
		AggroRange = 55,
		AttackRange = 4.5,
		AttackCooldown = 1.1,
		Windup = 0.35,
		XP = 6,
		Gold = { 1, 3 },
		Drops = { { Item = "RatTail", Chance = 0.5 } },
		RespawnTime = 5,
		-- (The code-driven scurry looked bad; it waits for a real animated rat. Procedural = "Scurry" brings it back.)
		DeathStyle = "Flip",
		Pack = { 2, 3 },
	},
	SlimeSmall = {
		DisplayName = "Slimeling",
		Model = "Slime",
		Scale = 0.55,
		Health = 25,
		Damage = 5,
		WalkSpeed = 11,
		AggroRange = 40,
		AttackRange = 3,
		AttackCooldown = 1.2,
		Windup = 0.4,
		XP = 4,
		Gold = { 1, 2 },
		Drops = { { Item = "SlimeGel", Chance = 0.25 } },
		RespawnTime = 5,
		DeathStyle = "Splat",
		Squishy = true,
	},
}

-- Chapter II's monsters: the chapter I ones the green ember has taken. Same bodies and moves, a little
-- tougher, mushrooms growing on them, and their blows leave Blight.
local function infected(base: string, changes: { [string]: any }): EnemyDef
	local def = table.clone(Enemies[base]) :: any
	def.Model = def.Model or base
	def.Infected = true
	def.Blight = 1
	def.Health = math.floor(def.Health * 1.15)
	def.Drops = { { Item = "SporeCap", Chance = 0.5 } }
	for key, value in changes do
		def[key] = value
	end
	return def
end

Enemies.FungalHusk = infected("Skeleton", { DisplayName = "Fungal Husk", XP = 14, Gold = { 4, 7 } })
Enemies.HuskArcher = infected("SkeletonArcher", { DisplayName = "Husk Archer", XP = 16, Gold = { 5, 8 } })
Enemies.SporeRat = infected("Rat", { DisplayName = "Spore Rat", XP = 7, Gold = { 1, 3 } })
Enemies.Bloater = infected("Slime", {
	DisplayName = "Bloater",
	XP = 12,
	Gold = { 3, 6 },
	SplitInto = false, -- (it doesn't split: it bursts)
	BurstSpores = { Radius = 9, Blight = 2, DamageScale = 0.6 },
})

return Enemies
