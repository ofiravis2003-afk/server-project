--!strict
-- What Emberhold's townsfolk say when a player talks to them: their name and title, what they say first
-- (Lines, one page at a time), and more if asked (More). Action adds a button that does something
-- (Brakka's "Trade" opens her shop). Keyed by the townsperson's model name in the town.

export type Dialogue = { Name: string, Title: string, Lines: { string }, More: { string }?, Action: string? }

local Dialogues: { [string]: Dialogue } = {
	GateGuard = {
		Name = "Gate Guard",
		Title = "Keeper of the Descent",
		Lines = {
			"Another one for the Well? Show me your hand. Good, the Brand's still warm.",
			"Down there the dead still guard their king's halls. Strike first, and don't stop to listen to them.",
		},
		More = {
			"Every floor has a Wardstone by the stairs you come down. Light it. Every stone lit pushes the ash back a little further.",
			"If you fall, the Brand drags you back to the last stone. It always does. I've just never asked what it charges.",
			"Come back alive. Most of you don't, the first time.",
		},
	},
	Aldric = {
		Name = "Aldric Vane",
		Title = "Master of the Adventurers' Guild",
		Lines = {
			"Welcome to Emberhold. That mark on your hand is the Guild Brand. Wear it with pride.",
			"Below us, the old Wardstones are going dark, and the ash is climbing through them. Go down and light them again. Bring back whatever you find.",
		},
		More = {
			"The Brand is what lights the stones. And if you fall, it brings you home. No one else in the world can promise you that.",
			"The wall behind me holds the names of those who didn't come home. Read it, if you want. Then go and make sure yours isn't added.",
		},
		Action = "Quests",
	},
	Brakka = {
		Name = "Brakka",
		Title = "Blacksmith",
		Lines = { "Don't just stand there dripping on my floor. Buying, selling, or getting that blade sharpened?" },
		More = {
			"My family's been smiths since before the mountain fell. Valdren's best, they say. Not that it did anyone much good.",
			"Bring me bones and scraps from below. Old Valdren steel remembers what it was. I just have to remind it.",
		},
		Action = "Trade",
	},
	Thorne = {
		Name = "Thorne",
		Title = "Ironhide Armory",
		Lines = { "Ironhide Armory. Plate, scale, leather, robes. Pick what suits how you fight, not how you look." },
		More = {
			"This eye? Left it a long way down. Something there breathes frost.",
			"Forty years I've known Aldric. Forty years, and he hasn't aged a day. Good blood, he says.",
			"...Forget I said that.",
		},
		Action = "Trade",
	},
	Seraphine = {
		Name = "Seraphine",
		Title = "The Gilded Tome",
		Lines = { "Oh! A new face! Have you been down yet? Did you see writing down there? Pages? Anything?" },
		More = {
			"Ilvane, the old king's wizard, built the Wardstones. She kept a journal, and it was torn apart when the city fell.",
			"If anyone knew how to stop the ash for good, it was her. Find her pages and bring them to me. Please! I'll make it worth your while.",
		},
		Action = "Quests",
	},
	OldPip = {
		Name = "Old Pip",
		Title = "The Sunken Tankard",
		Lines = { "Sit, sit. First drink's on the house... once I have drinks again. The supply wagon's late." },
		More = {
			"My boy went down last spring. Floor twelve, they say. Never came back up.",
			"If you ever get that deep, keep an eye out for a dented helmet with a fox painted on it. That's all I ask.",
			"Funny thing. Aldric's been coming in here thirty years and I've never once seen him eat. Not a crumb.",
		},
		Action = "Quests",
	},
}

return Dialogues
