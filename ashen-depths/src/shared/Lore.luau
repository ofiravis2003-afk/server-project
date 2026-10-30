--!strict
-- Ilvane's journal: the pages of the court wizard who built the Wardstones, torn and scattered when Valdren
-- fell. Each lies on a lectern in the treasure room of its floor; reading one keeps it (data.Pages[id]) and
-- Seraphine wants them all. Chapter I tells the night the city fell, and ends on what waits beneath the gate.
-- Chapter II (with Config.ChapterII on) adds Ilvane's pages on the green seed (Set "Ilvane2") and the torn pages
-- of Captain Mira Fell's patrol journal (Set "Patrol"). Set is nil for chapter I's pages.

local Config = require(script.Parent.Config)

export type Page = { Id: string, Floor: number, Title: string, Text: string, Set: string? }

local Lore = {}

Lore.Pages = {
	{
		Id = "Drought",
		Floor = 2,
		Title = "The Ninth Year of the Drought",
		Text = "The King has stopped sleeping. He counts the grey in his beard each morning and calls it a sickness.\n\nToday he asked me how long a man may live. I told him the truth. He did not like it.\n\nTonight the miners were sent below the mountain. Not for silver. He would not say for what.",
	},
	{
		Id = "BlackFlame",
		Floor = 4,
		Title = "The Black Flame",
		Text = "They found a fire at the root of the mountain. It gives no light. It gives no heat.\n\nThe foreman stood beside it for an hour, and when he came up he could not remember his mother's name. He laughed about it.\n\nBy morning he could not remember his own.",
	},
	{
		Id = "Oath",
		Floor = 6,
		Title = "The King's Oath",
		Text = "Malachar gathered the whole army in the square and made them swear: to guard their King beyond death itself.\n\nTen thousand voices said it together. I felt the words settle into the stone.\n\nI should have said something. I was afraid that he would ask me to swear too.",
	},
	{
		Id = "Fall",
		Floor = 7,
		Title = "The Night the Mountain Fell",
		Text = "He touched it.\n\nThe ground screamed. The towers bent like candles. And under the noise I heard something worse: the whole city forgetting itself at once. Mothers, names, songs, all of it turning to ash.\n\nOnly the oath remained. The soldiers still stood at their posts. They just no longer knew why.",
	},
	{
		Id = "Wardstones",
		Floor = 9,
		Title = "Stones Against the Ash",
		Text = "The ash rises like breath from below. I have built a stone to hold it back, one on every level I can still reach.\n\nThey work, but only while a fire burns in them. My own fire is not enough to keep them all lit for long.\n\nOne by one, they will go dark. I am sorry, whoever reads this. I could only buy you time.",
	},
	{
		Id = "LastKnight",
		Floor = 11,
		Title = "The Last Knight",
		Text = "Ser Hadric, captain of the King's guard, will stay at the sealed gate. He asked me for one thing: \"Do not let me forget my name.\"\n\nI carved it into his armour, over the heart.\n\nIf you meet him, traveller, read it to him. Then do what he can no longer do. Let him rest.",
	},
	{
		Id = "ThoseWhoCome",
		Floor = 13,
		Title = "Those Who Will Come",
		Text = "I dreamed of people with fire on their hands, climbing down the old stairs and lighting my stones again, one after another.\n\nI do not know who gives them that fire.\n\nI hope they are kinder than I was. I hope they ask what it costs.",
	},
	{
		Id = "BeneathTheGate",
		Floor = 14,
		Title = "Beneath the Gate",
		Text = "There is something beneath the sealed gate that the Black Flame did not make. A small green fire, older than the mountain. It does not know anyone's name. It never has.\n\nThe Flame keeps away from it.\n\nIf it ever wakes, the Flame will be the least of your troubles.",
	},
} :: { Page }

if Config.ChapterII then
	for _, page in {
		{
			Id = "TheSeed",
			Set = "Ilvane2",
			Floor = 17,
			Title = "The Seed",
			Text = "Below the Flame the miners struck a seam of soft black earth, and in it a green spark no bigger than a seed.\n\nIt was warm. Everything near it had begun to grow: moss on bare iron, roots in the stone, a white thread in the palm of the man who picked it up.\n\nWe sealed the seam. The man went in with it. By then, he asked us to.",
		},
		{
			Id = "PatrolDay3",
			Set = "Patrol",
			Floor = 19,
			Title = "Ninth Patrol, Day 3",
			Text = "Eight of us. Aldric came to the Well himself to see us off, which he has never done. He gave me the old words for the sealed gate, to speak to the knight.\n\nI asked how he knew them. He smiled and said, \"Read enough and you learn things.\"\n\nThe knight heard the words and stepped aside. I don't think he was looking at us.",
		},
		{
			Id = "ToldTheKing",
			Set = "Ilvane2",
			Floor = 22,
			Title = "What I Told the King",
			Text = "Malachar wanted it, of course. A fire that makes things grow, for a man who feared only death.\n\nI told him the truth, for once. It does not give life. It takes whatever lives and makes it part of one thing, and that thing has no name and does not want one.\n\nHe laughed. So I told him it had gone out.",
		},
		{
			Id = "PatrolDay19",
			Set = "Patrol",
			Floor = 23,
			Title = "Ninth Patrol, Day 19",
			Text = "The Toad took Corin, Wren and Tilda at the river. Five of us left.\n\nWe made camp where the rock opens out and carved all eight names on the wall, in case.\n\nJory found a mushroom growing in his boot and we laughed, for the first time in days. Sten's cough has gone white.",
		},
		{
			Id = "PatrolDay31",
			Set = "Patrol",
			Floor = 24,
			Title = "Ninth Patrol, Day 31",
			Text = "Sten has stopped coughing. He sits by the fire and smiles and does not eat. Something is growing under his collar.\n\nAldric gave me a sealed letter, to open at this depth. I opened it tonight.\n\nIt says only: \"Go on. Do not come back until it is done.\"",
		},
		{
			Id = "TheLid",
			Set = "Ilvane2",
			Floor = 26,
			Title = "The Lid",
			Text = "I understand now why the Black Flame sits where it sits. It is not feeding on this place. It is lying on top of it.\n\nEvery memory it burns gives heat, and the heat keeps the seed asleep. A lid, and a terrible one.\n\nI have spent my life trying to put that fire out.",
		},
		{
			Id = "TornOut",
			Set = "Patrol",
			Floor = 27,
			Title = "The Page She Tore Out",
			Text = "I tore this out, so the Guild would never find it in my journal.\n\nEach time one of us fell and woke at the stone, we came back with a little less. I can't remember my mother's voice. Jory can't remember his own name.\n\nAldric knew. He sent us to feed it.",
		},
		{
			Id = "RootToWater",
			Set = "Ilvane2",
			Floor = 29,
			Title = "As a Root Goes to Water",
			Text = "My stones press the ash down. I did not think what else they would press.\n\nThe weaker the Flame grows, the more the seed stirs. Whoever lights my stones helps one fire and wakes the other. I have checked the sums a hundred times.\n\nForgive me. When it wakes, it will go to the Flame, as a root goes to water.",
		},
	} :: { Page } do
		table.insert(Lore.Pages, page)
	end
end

Lore.ById = {} :: { [string]: Page }
Lore.ByFloor = {} :: { [number]: Page }
for _, page in Lore.Pages do
	Lore.ById[page.Id] = page
	Lore.ByFloor[page.Floor] = page
end

-- How many pages there are in a set, and how many of them are in `found` (data.Pages).
function Lore.SetSize(set: string?): number
	local size = 0
	for _, page in Lore.Pages do
		if page.Set == set then
			size += 1
		end
	end
	return size
end

function Lore.CountIn(found: { [string]: any }?, set: string?): number
	local count = 0
	for id in found or {} do
		local page = Lore.ById[id]
		if page and page.Set == set then
			count += 1
		end
	end
	return count
end

-- Whose hand a page is in (the top line of the sheet).
function Lore.From(page: Page): string
	return if page.Set == "Patrol"
		then "From the journal of Captain Mira Fell, the Ninth Patrol"
		else "From the journal of Ilvane, court wizard of Valdren"
end

return Lore
