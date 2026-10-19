--!strict
-- Ilvane's journal: the pages of the court wizard who built the Wardstones, torn and scattered when Valdren
-- fell. Each lies on a lectern in the treasure room of its floor; reading one keeps it (data.Pages[id]) and
-- Seraphine wants them all. Chapter I tells the night the city fell, and ends on what waits beneath the gate.

export type Page = { Id: string, Floor: number, Title: string, Text: string }

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

Lore.ById = {} :: { [string]: Page }
Lore.ByFloor = {} :: { [number]: Page }
for _, page in Lore.Pages do
	Lore.ById[page.Id] = page
	Lore.ByFloor[page.Floor] = page
end

return Lore
