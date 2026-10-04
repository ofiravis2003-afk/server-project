--!strict
-- The game's two fonts, in one place so the whole look can be changed here.
--   Title: an old hand-lettered fantasy font for names and headings (eggs, dragons, islands, Elder Ember).
--   Body:  a clean bold font for numbers, buttons and sentences, easy to read on a phone.
--   Number: the same clean font, extra bold, for the big Embers counter.
--   Text: the clean font, lighter, for long lines like Elder Ember's speech.

return {
	Title = Font.fromEnum(Enum.Font.Fondamento),
	Body = Font.fromEnum(Enum.Font.GothamBold),
	Number = Font.fromEnum(Enum.Font.GothamBlack),
	Text = Font.fromEnum(Enum.Font.GothamMedium),
}
