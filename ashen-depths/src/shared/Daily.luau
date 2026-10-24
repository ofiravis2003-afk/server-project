--!strict
-- Reasons to come back every day (DailyService on the server, client/common/Daily on screen):
--   Rewards: a gift for the first visit of each day (UTC). Days in a row climb the ladder below, day 7 being an
--   Epic piece of armor; after day 7 it starts over at day 1, and a missed day starts it over too.
--   Tasks: three tasks a day, picked from Tasks for each player, paid the moment they're done.

local Daily = {}

export type Reward = { Text: string, Gold: number?, Items: { { Item: string, Count: number } }?, EpicArmor: boolean? }

Daily.Rewards = {
	{ Text = "150 gold", Gold = 150 },
	{ Text = "2 Health Potions", Items = { { Item = "HealthPotion", Count = 2 } } },
	{ Text = "300 gold", Gold = 300 },
	{ Text = "Ironskin Tonic + Swiftness Draught", Items = { { Item = "IronskinTonic", Count = 1 }, { Item = "SwiftnessDraught", Count = 1 } } },
	{ Text = "500 gold", Gold = 500 },
	{ Text = "2 Greater Health Potions", Items = { { Item = "GreaterHealthPotion", Count = 2 } } },
	{ Text = "An Epic armor piece!", EpicArmor = true },
} :: { Reward }

export type Task = { Id: string, Text: string, Kind: "Kill" | "Boss" | "Chest" | "Floor", Target: string?, Count: number, Gold: number, XP: number }

-- Kill: slay Count monsters (of Target, or any); Boss: defeat Count bosses; Chest: open Count chests;
-- Floor: go down Count floors.
Daily.Tasks = {
	{ Id = "Slay", Text = "Slay 40 monsters", Kind = "Kill", Count = 40, Gold = 200, XP = 150 },
	{ Id = "Skeletons", Text = "Put 15 skeletons to rest", Kind = "Kill", Target = "Skeleton", Count = 15, Gold = 180, XP = 140 },
	{ Id = "Archers", Text = "Silence 8 skeleton archers", Kind = "Kill", Target = "SkeletonArcher", Count = 8, Gold = 220, XP = 160 },
	{ Id = "Chests", Text = "Open 3 chests", Kind = "Chest", Count = 3, Gold = 250, XP = 150 },
	{ Id = "Descend", Text = "Go down 5 floors", Kind = "Floor", Count = 5, Gold = 300, XP = 250 },
	{ Id = "Boss", Text = "Defeat a boss", Kind = "Boss", Count = 1, Gold = 600, XP = 500 },
} :: { Task }

Daily.ById = {} :: { [string]: Task }
for _, task in Daily.Tasks do
	Daily.ById[task.Id] = task
end

Daily.TasksPerDay = 3

-- Today's number (days since 1970, UTC): the same for every server.
function Daily.Today(): number
	return os.time() // 86400
end

return Daily
