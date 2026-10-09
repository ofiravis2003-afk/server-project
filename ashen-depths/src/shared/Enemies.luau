--!strict
-- Every enemy type: its stats and its rewards.
--   Windup: seconds the enemy shows its attack coming before the hit lands (time to step away)
--   Animations: published animation ids for the enemy's own 3D model (ServerStorage.EnemyModels.<name>).
--               Any that are missing are skipped: no walk = it glides, no death = it just falls over.
--   AnimationSpeeds: play some clips faster (Tripo made the attack and death 5 seconds long).
--   DeathFall: { Drop, From, To }: the death clip was made at the model's original tiny size, so its fall
--              is too short once the model is scaled up. The body is lowered `Drop` studs between
--              `From` and `To` seconds of the clip (clip time, before AnimationSpeeds).
--   ModelYaw: degrees to turn the model's facing, when its animations face another way than its
--             standing pose (the Tripo skeleton's animations face backwards: 180).

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
	Animations: { Idle: string?, Walk: string?, Attack: string?, Hit: string?, Death: string? }?,
	AnimationSpeeds: { [string]: number }?,
	ModelYaw: number?,
	DeathFall: { Drop: number, From: number, To: number }?,
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
		Animations = {
			Idle = "rbxassetid://84669635179600",
			Walk = "rbxassetid://138036023263764",
			Attack = "rbxassetid://83535294193875",
			Hit = "rbxassetid://132608517614379",
			Death = "rbxassetid://101347829567581",
		},
		AnimationSpeeds = { Attack = 2.8, Death = 1.8 },
		ModelYaw = 180,
		DeathFall = { Drop = 2.3, From = 1.0, To = 1.6 },
	},
}

return Enemies
