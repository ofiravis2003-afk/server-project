--!strict
-- Every enemy type: its stats and its rewards.
--   Windup: seconds the enemy shows its attack coming before the hit lands (time to step away)
--   Animations: published animation ids for the enemy's own 3D model (ServerStorage.EnemyModels.<name>).
--               Any that are missing are skipped: no walk = it glides, no death = it just falls over.

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
		Windup = 0.45,
		XP = 12,
		Gold = { 3, 6 },
		RespawnTime = 5,
		Animations = {
			Idle = "rbxassetid://84669635179600",
		},
	},
}

return Enemies
