--!strict
-- Parties: up to MAX_SIZE adventurers who go down the Great Well together and come back up together.
--   In Emberhold a player invites another (client/hub/Party); the invite waits INVITE_SECONDS for Accept or
--   Decline. The one who invited first leads; only the leader invites and leads the way down. If the
--   leader leaves, the next member leads; a party of one is no party.
--   Travelling, the party goes along in the teleport data (PartyService.TeleportData) and is put back
--   together on arrival, whoever lands first.
-- Every member is told the party's state ("PartyUpdated": leader and members, or nil when not in one).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(script.Parent.RateLimiter)

local PartyService = {}

local MAX_SIZE = 4
local INVITE_SECONDS = 30

export type Party = { Id: string, Leader: Player?, LeaderId: number, Members: { Player } }

local partyOf: { [Player]: Party } = {}
local byId: { [string]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invitee -> inviter -> when it runs out

local updatedRemote = Remotes.Event("PartyUpdated")
local inviteRemote = Remotes.Event("PartyInvite")
local notifyRemote = Remotes.Event("Notify")
local limiter = RateLimiter.new(0.5)

local function push(party: Party?, extra: { Player }?)
	local state = nil
	if party then
		local members = {}
		for _, member in party.Members do
			table.insert(members, { UserId = member.UserId, Name = member.DisplayName })
		end
		state = { LeaderId = party.LeaderId, Members = members }
	end
	if party then
		for _, member in party.Members do
			updatedRemote:FireClient(member, state)
		end
	end
	for _, player in extra or {} do
		updatedRemote:FireClient(player, nil)
	end
end

local function remove(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	if #party.Members <= 1 then
		-- a party of one is no party
		local last = party.Members[1]
		if last then
			partyOf[last] = nil
		end
		byId[party.Id] = nil
		push(nil, if last then { player, last } else { player })
		if last and last.Parent == Players then
			notifyRemote:FireClient(last, "Your party has broken up.")
		end
		return
	end
	if party.Leader == player or party.LeaderId == player.UserId then
		party.Leader = party.Members[1]
		party.LeaderId = party.Members[1].UserId
		notifyRemote:FireClient(party.Members[1], "You lead the party now.")
	end
	push(party, { player })
end

local function add(party: Party, player: Player)
	if partyOf[player] == party then
		return
	end
	remove(player)
	partyOf[player] = party
	table.insert(party.Members, player)
	if player.UserId == party.LeaderId then
		party.Leader = player
	end
end

-- The party a player is in (nil when alone).
function PartyService.Of(player: Player): Party?
	return partyOf[player]
end

-- Who goes with this player: their party's members in this server, or just them.
function PartyService.Members(player: Player): { Player }
	local party = partyOf[player]
	if not party then
		return { player }
	end
	return table.clone(party.Members)
end

function PartyService.IsLeader(player: Player): boolean
	local party = partyOf[player]
	return party == nil or party.LeaderId == player.UserId
end

function PartyService.LeaderName(player: Player): string
	local party = partyOf[player]
	local leader = party and party.Leader
	return if leader then leader.DisplayName else "your party's leader"
end

-- What to carry through a teleport so the party is put back together on the other side.
function PartyService.TeleportData(player: Player): { [string]: any }
	local party = partyOf[player]
	if not party then
		return {}
	end
	return { PartyId = party.Id, PartyLeader = party.LeaderId }
end

local function onInvite(player: Player, target: Player)
	if target == player or target.Parent ~= Players then
		return
	end
	local party = partyOf[player]
	if party and party.LeaderId ~= player.UserId then
		notifyRemote:FireClient(player, "Only the party's leader can invite.")
		return
	end
	if party and #party.Members >= MAX_SIZE then
		notifyRemote:FireClient(player, `A party is {MAX_SIZE} adventurers at most.`)
		return
	end
	if partyOf[target] and partyOf[target] == party then
		return
	end
	if partyOf[target] then
		notifyRemote:FireClient(player, `{target.DisplayName} is already in a party.`)
		return
	end
	local theirs = invites[target] or {}
	invites[target] = theirs
	theirs[player] = os.clock() + INVITE_SECONDS
	inviteRemote:FireClient(target, player, INVITE_SECONDS)
	notifyRemote:FireClient(player, `You invited {target.DisplayName} to your party.`)
end

local function onAccept(player: Player, inviter: Player)
	local mine = invites[player]
	local expires = mine and mine[inviter]
	if mine then
		mine[inviter] = nil
	end
	if not expires or os.clock() > expires or inviter.Parent ~= Players then
		notifyRemote:FireClient(player, "That invite has run out.")
		return
	end
	local party = partyOf[inviter]
	if party and party.LeaderId ~= inviter.UserId then
		notifyRemote:FireClient(player, `{inviter.DisplayName} no longer leads a party.`)
		return
	end
	if not party then
		local fresh: Party = { Id = HttpService:GenerateGUID(false), Leader = inviter, LeaderId = inviter.UserId, Members = {} }
		party = fresh
		byId[fresh.Id] = fresh
		add(fresh, inviter)
	end
	local p = party :: Party
	if #p.Members >= MAX_SIZE then
		notifyRemote:FireClient(player, "That party is full.")
		return
	end
	add(p, player)
	invites[player] = nil
	for _, member in p.Members do
		notifyRemote:FireClient(member, `{player.DisplayName} joined the party.`)
	end
	push(p)
end

function PartyService.Start()
	Remotes.Event("PartyAction").OnServerEvent:Connect(function(player: Player, action: any, other: any)
		if not limiter:Check(player) then
			return
		end
		if action == "Leave" then
			local party = partyOf[player]
			remove(player)
			if party then
				for _, member in party.Members do
					notifyRemote:FireClient(member, `{player.DisplayName} left the party.`)
				end
			end
			return
		end
		if typeof(other) ~= "Instance" or not other:IsA("Player") then
			return
		end
		if action == "Invite" then
			onInvite(player, other)
		elseif action == "Accept" then
			onAccept(player, other)
		elseif action == "Decline" then
			local mine = invites[player]
			if mine and mine[other] then
				mine[other] = nil
				notifyRemote:FireClient(other, `{player.DisplayName} declined your invite.`)
			end
		end
	end)

	-- Arriving by teleport with a party: put it back together.
	local function onPlayer(player: Player)
		local ok, data = pcall(function()
			return player:GetJoinData().TeleportData
		end)
		if not ok or type(data) ~= "table" or type(data.PartyId) ~= "string" then
			return
		end
		local party = byId[data.PartyId]
		if not party then
			local fresh: Party = { Id = data.PartyId, Leader = nil, LeaderId = tonumber(data.PartyLeader) or player.UserId, Members = {} }
			party = fresh
			byId[fresh.Id] = fresh
		end
		add(party :: Party, player)
		if not (party :: Party).Leader then
			-- (until the leader arrives, if they do, the first one here leads)
			local p = party :: Party
			task.delay(15, function()
				if byId[p.Id] == p and not p.Leader and p.Members[1] then
					p.Leader = p.Members[1]
					p.LeaderId = p.Members[1].UserId
					push(p)
				end
			end)
		end
		push(party)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		for _, mine in invites do
			mine[player] = nil
		end
		remove(player)
	end)
end

return PartyService
