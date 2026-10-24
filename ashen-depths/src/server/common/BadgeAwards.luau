--!strict
-- Roblox badges (ids in shared/Config Badges; one left at 0 isn't given yet): checked before giving, so each is
-- asked of Roblox at most once per player per server.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BadgeAwards = {}

local given: { [Player]: { [string]: boolean } } = {}

function BadgeAwards.Give(player: Player, name: string)
	local id = (Config.Badges :: any)[name] :: number?
	if not id or id == 0 then
		return
	end
	local mine = given[player] or {}
	given[player] = mine
	if mine[name] then
		return
	end
	mine[name] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			local awarded, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
			if not awarded then
				warn(`[BadgeAwards] {name} for {player.Name}: {err}`)
				mine[name] = nil -- (try again next time)
			end
		end
	end)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	given[player] = nil
end)

return BadgeAwards
