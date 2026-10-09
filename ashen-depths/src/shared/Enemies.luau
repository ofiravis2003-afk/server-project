--!strict
-- Every enemy type: its stats and its rewards.
--   Windup: seconds the enemy shows its attack coming before the hit lands (time to step away)
--   Model: which 3D model in ServerStorage.EnemyModels to build from (default: the enemy's own name)
--   Scale: size compared to that model (the little slimes are small slimes)
--   Animations: published animation ids for the enemy's own 3D model (ServerStorage.EnemyModels.<name>).
--               Any that are missing are skipped: no walk = it glides, no death = it just falls over.
--   AnimationSpeeds: play some clips faster (Tripo made the attack and death 5 seconds long).
--   CrumbleInto: on death the body flinches (its Hit clip) and after `At` seconds shatters: it vanishes in a
--                burst of dust, bones fly out and tumble across the floor, and this dungeon prop stays behind.
--                Its own death clip is skipped (Tripo's looked like a stumble).
--   ModelYaw: degrees to turn the model's facing, when its animations face another way than its
--             standing pose (the Tripo skeleton's animations face backwards: 180).
--   Ranged: keeps its distance and shoots: backs off when a player is closer than KeepAway, shows a red
--           aiming line for `Windup` seconds, then fires an arrow that hits whoever is still within
--           HitRadius of where it was aimed. AttackRange is then the shooting range.
--   HeldProp: a dungeon prop held in a hand bone (the archer's bow).
--   DeathStyle: "Splat" bursts into goo instead of falling over.
--   SplitInto: on death, this many of that enemy pop out where it died (slimes split in two).
--   Squishy: wobbles as it moves (drawn by the players' screens).
--   Procedural: "Scurry" = no animation clips; the body is moved by code (bouncing run, lunging bite).
--   Pack: comes in a group of this many (min, max) in one spawn.

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
	ModelYaw: number?,
	CrumbleInto: { Prop: string, At: number }?,
	Ranged: { KeepAway: number, ProjectileSpeed: number, HitRadius: number }?,
	HeldProp: { Prop: string, Bone: string }?,
	DeathStyle: string?,
	SplitInto: { Name: string, Count: number }?,
	Squishy: boolean?,
	Procedural: string?,
	Pack: { number }?,
}

local SKELETON_ANIMATIONS = {
	Idle = "rbxassetid://84669635179600",
	Walk = "rbxassetid://138036023263764",
	Attack = "rbxassetid://83535294193875",
	Hit = "rbxassetid://132608517614379",
	Death = "rbxassetid://101347829567581",
}

local Enemies: { [string]: EnemyDef } = {
	Skeleton = {
		DisplayName = "Skeleton",
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
		Animations = SKELETON_ANIMATIONS,
		AnimationSpeeds = { Attack = 2.8, Death = 1.8 },
		ModelYaw = 180,
		CrumbleInto = { Prop = "BonePile", At = 0.22 },
	},
	SkeletonArcher = {
		DisplayName = "Skeleton Archer",
		Model = "Skeleton",
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
		-- Until the bow-shooting clip arrives, the archer swings like the skeleton.
		Animations = SKELETON_ANIMATIONS,
		AnimationSpeeds = { Attack = 2.8, Death = 1.8 },
		ModelYaw = 180,
		CrumbleInto = { Prop = "BonePile", At = 0.22 },
		Ranged = { KeepAway = 12, ProjectileSpeed = 80, HitRadius = 3 },
		HeldProp = { Prop = "Bow", Bone = "mixamorig:LeftHand" },
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
		ModelYaw = 180,
		Procedural = "Scurry",
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
