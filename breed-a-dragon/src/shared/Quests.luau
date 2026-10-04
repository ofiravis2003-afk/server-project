--!strict
-- The tutorial quest chain, in order. Each quest is finished by doing `Kind` `Count` times
-- (see QuestService.Record for where each Kind is counted). Elder Ember says `Elder` when you
-- talk to him during that quest, and `Target` is what the guide line on screen points at.

export type Quest = {
	Id: string,
	Kind: string, -- "Hatch" | "TalkElder" | "Collect" | "BuyEgg" | "Breed" | "HatchBred"
	Count: number,
	Reward: number, -- Embers
	Text: string, -- shown in the quest tracker
	Elder: { string },
	Target: string?, -- "Elder" | "Crystal" | "EggShop"
}

local Quests = {}

Quests.List = {
	{
		Id = "HatchGift",
		Kind = "Hatch",
		Count = 1,
		Reward = 20,
		Text = "Hatch your gift egg",
		Elder = { "Your egg is warming up in a nest at the bottom of your screen. When it's ready, press HATCH!" },
	},
	{
		Id = "MeetElder",
		Kind = "TalkElder",
		Count = 1,
		Reward = 10,
		Text = "Talk to Elder Ember",
		Target = "Elder",
		Elder = {
			"A fine hatchling! Look closely: no other dragon in the world has exactly the same genes.",
			"Dragons feed on Embers, the old magic of Skyreach. Tap the glowing Ember Crystals to collect them.",
		},
	},
	{
		Id = "Collect",
		Kind = "Collect",
		Count = 25,
		Reward = 15,
		Text = "Collect Embers from crystals",
		Target = "Crystal",
		Elder = { "Tap the orange Ember Crystals around the island. Your active dragons earn Embers for you too." },
	},
	{
		Id = "BuyEgg",
		Kind = "BuyEgg",
		Count = 1,
		Reward = 25,
		Text = "Buy an egg at the Egg Shop",
		Target = "EggShop",
		Elder = {
			"The Egg Shop is just over there. Better eggs hatch rarer dragons: the odds are written above each one.",
		},
	},
	{
		Id = "HatchBought",
		Kind = "Hatch",
		Count = 1,
		Reward = 30,
		Text = "Hatch the egg you bought",
		Elder = { "Your new egg is in a nest. Hatch it when it's ready!" },
	},
	{
		Id = "Breed",
		Kind = "Breed",
		Count = 1,
		Reward = 60,
		Text = "Breed two dragons (🐉 then 💞 Breed)",
		Elder = {
			"Now the real magic. Open 🐉, pick a dragon and press 💞 Breed.",
			"The baby gets genes from both parents... and sometimes a mutation neither of them has!",
		},
	},
	{
		Id = "HatchBred",
		Kind = "HatchBred",
		Count = 1,
		Reward = 100,
		Text = "Hatch your Bred Egg",
		Elder = { "Hatch the Bred Egg and see what your dragons made together." },
	},
} :: { Quest }

-- What Elder Ember says once every quest is done.
Quests.DoneElder = {
	"You are a true Keeper now.",
	"Fill your Dragon Index with rare genes. Breed well, and you might be the first in the whole world to discover a new dragon!",
	"The other islands of Skyreach are still lost in the clouds... but they won't stay hidden for long.",
}

-- The first thing a new player hears, before the first quest.
Quests.Intro = {
	"Ah... a new Keeper has come to Skyreach. I am Elder Ember, the oldest dragon left in the sky.",
	"Long ago the Great Storm broke our world into floating islands, and the dragons vanished with it.",
	"But their magic still glows in the Ember Crystals, and dragon eggs are waking up again.",
	"Here, take this egg. It's already warm. Raise dragons, breed them, and bring Skyreach back to life!",
}

function Quests.Get(step: number): Quest?
	return Quests.List[step]
end

return Quests
