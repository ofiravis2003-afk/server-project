--!strict
-- One-time changes to a save, run as it loads (DataService), when the game's shape changes under it.
--
-- Chapter II (Config.ChapterII): floors 16-30 become the Rotwood Caverns and The Hollow moves down to 31.
-- A player who had already gone past floor 15 was in the old Hollow: they keep it as a mark (HollowReached, for
-- the Hollow Walker title; the Deepest Descents board keeps their record as it was), and are set at the gate
-- of the caverns: floor 16 is their deepest and their checkpoint, so they can start there but walk the new
-- chapter's floors for themselves. Wardstones past 15 are dark again (the caverns' ones are rotted over).

local Migrations = {}

function Migrations.Apply(data: { [string]: any }, chapterII: boolean)
	if chapterII and not data.ChapterIIMoved then
		data.ChapterIIMoved = true
		if (data.DeepestFloor or 0) >= 16 or (data.Checkpoint or 0) > 16 then
			data.HollowReached = true
		end
		if (data.DeepestFloor or 0) > 16 then
			data.DeepestFloor = 16
		end
		if (data.Checkpoint or 0) > 16 then
			data.Checkpoint = 16
		end
		if (data.WardLit or 0) > 15 then
			data.WardLit = 15
		end
	end
end

return Migrations
