--!strict
-- The game's fonts, in one place so the whole look can be changed here.
--   Title: an old carved-stone fantasy font for names, headings and boss names.
--   Body:  a clean bold font for numbers, buttons and sentences, easy to read on a phone.
--   Number: the same clean font, extra bold, for damage numbers and gold.
--   Text: the clean font, lighter, for long lines like NPC dialog.

return {
	Title = Font.fromEnum(Enum.Font.Fondamento),
	Body = Font.fromEnum(Enum.Font.GothamBold),
	Number = Font.fromEnum(Enum.Font.GothamBlack),
	Text = Font.fromEnum(Enum.Font.GothamMedium),
}
