--!strict
-- Loads and saves every player's progress.
--
-- Session locking: while a server has a player loaded, it writes its JobId into the save.
-- Another server (the player hopped servers fast) waits for that lock to be released, so two
-- servers never overwrite each other's progress. A lock older than LOCK_EXPIRE_SECONDS came
-- from a crashed server and can be taken over.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local DataTemplate = require(script.Parent.DataTemplate)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_EXPIRE_SECONDS = 30 * 60
local LOAD_ATTEMPTS = 6
local LOAD_RETRY_DELAY = 5
local SAVE_ATTEMPTS = 3

type Profile = {
	Data: { [string]: any },
	CanSave: boolean,
	Released: boolean,
}

local DataService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Profile } = {}
local releasingUserIds: { [number]: boolean } = {} -- final save still running for these players
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}
local notifyRemote = Remotes.Event("Notify")

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

-- Fills in any field that exists in the template but is missing from an older save.
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Studio refuses DataStore calls until the place is published and
-- "Enable Studio Access to API Services" is turned on.
local function isStudioAccessError(err: any): boolean
	if not RunService:IsStudio() then
		return false
	end
	local message = tostring(err)
	return message:find("StudioAccessToApisNotAllowed") ~= nil
		or message:find("403") ~= nil
		or message:find("publish") ~= nil
end

local function loadRecord(player: Player): (boolean, { [string]: any }?, string?)
	local lastError = "unknown error"

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOtherServer = false
		local isLastAttempt = attempt == LOAD_ATTEMPTS

		local success, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(old: any): any
				lockedByOtherServer = false
				local record: { [string]: any } = old or {}
				local lock = record.Lock
				local lockIsFresh = lock ~= nil
					and lock.JobId ~= game.JobId
					and os.time() - lock.Time < LOCK_EXPIRE_SECONDS
				if lockIsFresh and not isLastAttempt then
					lockedByOtherServer = true
					return nil -- cancel the write and try again shortly
				end
				record.Lock = { JobId = game.JobId, Time = os.time() }
				return record
			end)
		end)

		if success and not lockedByOtherServer then
			return true, result, nil
		end

		if not success then
			lastError = tostring(result)
			if isStudioAccessError(result) then
				return false, nil, "studio"
			end
			warn(`[DataService] Load attempt {attempt} for {player.Name} failed: {lastError}`)
		end

		if player.Parent == nil then
			return false, nil, "left"
		end
		task.wait(LOAD_RETRY_DELAY)
	end

	return false, nil, lastError
end

-- Returns whether the data is safely stored (false if saving is off, failed, or was refused).
local function saveProfile(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave then
		return false
	end
	if profile.Released and not release then
		return false
	end

	for attempt = 1, SAVE_ATTEMPTS do
		local lostLock = false
		local success, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old: any): any
				lostLock = false
				if profile.Released and not release then
					return nil -- the final save already ran; don't re-lock a player who left
				end
				local record: { [string]: any } = old or {}
				if record.Lock and record.Lock.JobId ~= game.JobId then
					-- Another server took this player over. Its data is newer; never overwrite it.
					lostLock = true
					return nil
				end
				record.Data = profile.Data
				record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return record
			end)
		end)

		if success then
			if lostLock then
				profile.CanSave = false
				if player.Parent ~= nil then
					player:Kick("Your game was opened on another server. Please rejoin.")
				end
				return false
			end
			return true
		end

		warn(`[DataService] Save attempt {attempt} for {player.Name} failed: {err}`)
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

local function onPlayerAdded(player: Player)
	-- Rejoined the same server quickly: let the previous session finish saving first.
	while releasingUserIds[player.UserId] do
		task.wait(0.5)
	end

	local loaded, record, reason = loadRecord(player)
	if player.Parent == nil then
		-- Left while loading. If we did take the lock, give it back right away.
		if loaded then
			profiles[player] =
				{ Data = (record and record.Data) or deepCopy(DataTemplate), CanSave = true, Released = true }
			saveProfile(player, true)
			profiles[player] = nil
		end
		return
	end

	local profile: Profile
	if loaded then
		local data = (record and record.Data) or deepCopy(DataTemplate)
		reconcile(data, DataTemplate)
		profile = { Data = data, CanSave = true, Released = false }
	elseif reason == "studio" then
		warn(
			"[DataService] Saving is OFF: turn on Game Settings > Security > Enable Studio Access to API Services. "
				.. "Playing with fresh data that will not be saved."
		)
		profile = { Data = deepCopy(DataTemplate), CanSave = false, Released = false }
		notifyRemote:FireClient(player, "Saving is off in Studio (API access disabled). Progress will not be kept.")
	else
		warn(`[DataService] Could not load {player.Name}: {reason}`)
		player:Kick("We couldn't load your adventurer. Please rejoin in a minute!")
		return
	end

	local data = profile.Data
	local now = os.time()
	if data.FirstJoinTime == 0 then
		data.FirstJoinTime = now
	end
	data.LastJoinTime = now
	data.JoinCount += 1

	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Released = true
	releasingUserIds[player.UserId] = true
	saveProfile(player, true)
	profiles[player] = nil
	releasingUserIds[player.UserId] = nil
end

-- Returns the player's live data table, or nil if it is not loaded (yet).
-- Change values in this table directly; it is saved automatically.
function DataService.GetData(player: Player): { [string]: any }?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Saves the player's data right away (used after a purchase). Returns whether it is stored;
-- in Studio with saving off it returns `true`, so purchases can still be tested there.
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if profile and not profile.CanSave and not profile.Released then
		return RunService:IsStudio()
	end
	return saveProfile(player, false)
end

-- Runs `callback(player, data)` every time a player's data finishes loading.
-- Register callbacks before calling DataService.Start().
function DataService.OnLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			profile.Released = true
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return DataService
