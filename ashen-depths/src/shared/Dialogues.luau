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
			"Another one for the Well? Good. The Guild pays by the floor.",
			"Down there the dead still guard their king's halls. Strike first, and don't stop to listen to them.",
		},
		More = {
			"If it goes bad, climb the rope in any floor's entrance. No shame in coming back alive.",
			"Past the fifth floor something digs graves for the living. Bring potions. Bring friends.",
		},
	},
	Aldric = {
		Name = "Aldric Vane",
		Title = "Master of the Adventurers' Guild",
		Lines = {
			"Welcome to Emberhold, adventurer. The Guild needs every blade it can get.",
			"Bring back what you find below. Treasure, relics... anything that still burns.",
		},
		More = {
			"The ash rises a little more every year. We go down so that it never reaches us.",
			"Why do so many go down? Because the Depths take so many. Don't trouble yourself with the Guild's reasons. Trouble yourself with coming back.",
		},
		Action = "Quests",
	},
	Brakka = {
		Name = "Brakka",
		Title = "Blacksmith",
		Lines = { "Don't just stand there dripping on my floor. Buying, selling, or getting that blade sharpened?" },
		Action = "Trade",
	},
	Thorne = {
		Name = "Thorne",
		Title = "Ironhide Armory",
		Lines = { "Armor? Not today. My forge is still cold. Come back when the Armory opens its doors." },
		More = {
			"This eye? Left it on the thirty-third floor. Something down there breathes frost.",
			"One day I'll go back for it. Or for whatever took it.",
		},
	},
	Seraphine = {
		Name = "Seraphine",
		Title = "The Gilded Tome",
		Lines = { "Oh! A new face! Have you been down yet? Did you see writing on the walls? Pages? Anything?" },
		More = {
			"Malachar's court wizard kept a spellbook. It was torn apart when the city fell.",
			"Every page is a spell nobody has cast in a thousand years. If you find one, bring it to me. Please! My shop isn't open yet, but I'll make it worth your while.",
		},
	},
	OldPip = {
		Name = "Old Pip",
		Title = "The Sunken Tankard",
		Lines = { "Sit, sit. First drink's on the house... once I have drinks again. The supply wagon's late." },
		More = {
			"My boy went down last spring. Floor twelve, they say. Never came back up.",
			"If you ever get that deep, keep an eye out for a dented helmet with a fox painted on it. That's all I ask.",
		},
		Action = "Quests",
	},
}

return Dialogues
