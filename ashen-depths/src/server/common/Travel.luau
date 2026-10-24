--!strict
-- Sends players to the other place (down the Well, up the rope): saves them, shows the travel card, teleports
-- them together, and tries once more if Roblox refuses. If it still fails, the card comes down and each
-- player is told what went wrong (Roblox's own reason), instead of being left on a loading screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local Travel = {}

local travelingRemote = Remotes.Event("Traveling")
local notifyRemote = Remotes.Event("Notify")

local function fail(player: Player, why: string)
	warn(`[Travel] {player.Name} could not travel: {why}`)
	travelingRemote:FireClient(player, "Cancel")
	notifyRemote:FireClient(player, `The way is blocked ({why}). Try again in a moment.`)
end

-- where: "Depths" or "Emberhold" (the card to show). Returns whether Roblox accepted the teleport.
function Travel.Go(players: { Player }, placeId: number, where: string, options: TeleportOptions?): boolean
	for _, player in players do
		DataService.SaveNow(player)
		travelingRemote:FireClient(player, where)
	end
	task.wait(0.5)
	local ok, err
	for _ = 1, 2 do
		local going = {}
		for _, player in players do
			if player.Parent == Players then
				table.insert(going, player)
			end
		end
		if #going == 0 then
			return false
		end
		ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, going, options)
		end)
		if ok then
			return true
		end
		task.wait(2)
	end
	for _, player in players do
		if player.Parent == Players then
			fail(player, tostring(err))
		end
	end
	return false
end

function Travel.Start()
	-- accepted, but failed on the way (the place didn't start, the player can't go there...)
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		fail(player, `{result.Name}: {message}`)
	end)
end

return Travel
