--!strict
-- The deepest floor each adventurer has reached, kept for all servers in one OrderedDataStore so the town's
-- board can show the best of everyone (the Depths writes, Emberhold reads).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboard = {}

local STORE = "DeepestFloor_v1"

local store: OrderedDataStore? = nil
local function getStore(): OrderedDataStore?
	if not store then
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, STORE)
		if ok then
			store = result
		end
	end
	return store
end

-- A player reached a new deepest floor (only ever goes up).
function Leaderboard.Record(player: Player, floor: number)
	task.spawn(function()
		local s = getStore()
		if not s then
			return
		end
		local ok, err = pcall(function()
			s:UpdateAsync(tostring(player.UserId), function(old: number?)
				if old and old >= floor then
					return nil
				end
				return floor
			end)
		end)
		if not ok then
			warn(`[Leaderboard] Could not record {player.Name}: {err}`)
		end
	end)
end

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Adventurer"
	return names[userId]
end

-- The best `count` (deepest first): { { Name, Floor } }, or nil if the store can't be reached now.
function Leaderboard.Top(count: number): { { Name: string, Floor: number } }?
	local s = getStore()
	if not s then
		return nil
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, count)
	if not ok or not pages then
		return nil
	end
	local list = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		table.insert(list, { Name = nameOf(tonumber(entry.key) or 0), Floor = entry.value })
	end
	return list
end

return Leaderboard
