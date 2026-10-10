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

export type HeldProp = { Prop: string, Bone: string, GripAngles: { number }?, GripOffset: { number }?, Scale: number? }

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
	RespawnTime: number,
	Model: string?,
	Scale: number?,
	Animations: { Idle: string?, Walk: string?, Attack: string?, Hit: string?, Death: string? }?,
	AnimationSpeeds: { [string]: number }?,
	AttackClips: { { Id: string, HitAt: number } }?,
	EliteAttackClips: { { Id: string, HitAt: number } }?,
	ModelYaw: number?,
	CrumbleInto: { Prop: string, At: number, AfterDeathClip: boolean?, FallBack: number?, FallAngle: number? }?,
	Ranged: { KeepAway: number, ProjectileSpeed: number, HitRadius: number }?,
	HeldProps: { HeldProp }?,
	EliteHeldProps: { HeldProp }?,
	DeathStyle: string?,
	SplitInto: { Name: string, Count: number }?,
	Squishy: boolean?,
	Procedural: string?,
	Pack: { number }?,
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

local Enemies: { [string]: EnemyDef } = {
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
		RespawnTime = 5,
		Animations = SWORD_ANIMATIONS,
		AnimationSpeeds = { Walk = 0.8 },
		AttackClips = SWORD_ATTACKS,
		EliteAttackClips = ELITE_SWORD_ATTACKS,
		-- Its blows land facing this way (the guard stance stands a little side-on).
		ModelYaw = -92,
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
		RespawnTime = 5,
		Animations = ARCHER_ANIMATIONS,
		-- Its clips stand side-on with the bow arm out; this turns the body so the arrow flies at the player.
		ModelYaw = 81,
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
		Health = 70,
		Damage = 9,
		WalkSpeed = 7,
		AggroRange = 40,
		AttackRange = 4,
		AttackCooldown = 1.6,
		Windup = 0.5,
		XP = 10,
		Gold = { 2, 5 },
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
		RespawnTime = 5,
		DeathStyle = "Splat",
		Squishy = true,
	},
}

return Enemies
