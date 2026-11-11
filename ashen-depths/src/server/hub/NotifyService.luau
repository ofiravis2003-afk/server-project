--!strict
-- Roblox notifications (shared/Config Notifications), sent from Emberhold through Open Cloud:
--   Asking: once, back in town after reaching floor 2 (a good moment, not the first minute), the player is asked
--   whether they want notifications from the game (Roblox's own prompt, client/hub/NotifyAsk; Roblox decides
--   who may be asked: 13 and older, not already in).
--   FriendDescending: a player goes down the Great Well, and their friends who said yes hear of it (Roblox
--   delivers at most one a day from a game to each player, so at most one a day here too).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.Parent.Common.DataService)

local NotifyService = {}

local MAX_FRIENDS = 20 -- told about one descent
local MAX_TRIES = 30 -- friends tried for one descent (most never said yes to notifications)
local SENDER_COOLDOWN = 3 * 3600 -- a player's descents tell their friends at most this often

local lastSent: { [number]: number } = {} -- sender's user id -> when their friends were last told
local toldToday: { [number]: number } = {} -- friend's user id -> the day they were last told (this server)

local function today(): number
	return os.time() // 86400
end

local function send(userId: number, messageId: string, category: string): boolean
	local ok, result = pcall(function()
		return HttpService:RequestAsync({
			Url = `https://apis.roblox.com/cloud/v2/users/{userId}/notifications`,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-api-key"] = HttpService:GetSecret(Config.Notifications.Secret) :: any,
			},
			Body = HttpService:JSONEncode({
				source = { universe = `universes/{game.GameId}` },
				payload = { message_id = messageId, type = "MOMENT" },
				join_experience = { launch_data = category },
				analytics_data = { category = category },
			}),
		})
	end)
	if not ok then
		warn(`[NotifyService] {category} to {userId}: {result}`)
		return false
	end
	local response = result :: any
	if not response.Success then
		-- (a friend who hasn't said yes to notifications from the game: expected, not worth a warning)
		if string.find(response.Body or "", "not opted in", 1, true) then
			return false
		end
		warn(`[NotifyService] {category} to {userId}: {response.StatusCode} {response.Body}`)
		return false
	end
	return true
end

-- A player pressed Descend at the Great Well: their friends who aren't in this town hear of it.
function NotifyService.FriendDescending(player: Player)
	local messageId = Config.Notifications.FriendDescending
	if messageId == "" or RunService:IsStudio() or not HttpService.HttpEnabled then
		return
	end
	local now = os.time()
	if now - (lastSent[player.UserId] or 0) < SENDER_COOLDOWN then
		return
	end
	lastSent[player.UserId] = now
	task.spawn(function()
		local ok, result = pcall(Players.GetFriendsAsync, Players, player.UserId)
		if not ok then
			return
		end
		local pages = result :: FriendPages
		local sent = 0
		local tried = 0
		while sent < MAX_FRIENDS and tried < MAX_TRIES do
			for _, friend in pages:GetCurrentPage() do
				local id = (friend :: any).Id :: number
				if sent >= MAX_FRIENDS or tried >= MAX_TRIES then
					break
				end
				if not Players:GetPlayerByUserId(id) and toldToday[id] ~= today() then
					toldToday[id] = today()
					tried += 1
					if send(id, messageId, "FriendDescending") then
						sent += 1
					end
				end
			end
			if pages.IsFinished or not pcall(pages.AdvanceToNextPageAsync, pages) then
				break
			end
		end
	end)
end

function NotifyService.Start()
	DataService.OnLoaded(function(player, data)
		-- once, back in town after floor 2; not in the visit where the like card comes (ShopService, floor 3)
		local likeCardNow = (data.DeepestFloor or 0) >= 3 and not data.AskedLike
		if (data.DeepestFloor or 0) >= 2 and not data.AskedNotify and not likeCardNow then
			data.AskedNotify = true
			task.delay(12, function()
				if player.Parent then
					Remotes.Event("AskNotify"):FireClient(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player.UserId] = nil
	end)
end

return NotifyService
