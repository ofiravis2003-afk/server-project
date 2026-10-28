--!strict
-- Titles (shared/Titles), in both places: which ones a player has earned, the one they wear (data.Title), and
-- the tag over every player's head: their title, then their Guild rank, VIP and Founder number.
-- Also keeps the counts some titles need: kills by enemy (OnKill) and the best damage per second in the
-- Training Yard (OnDps). A newly earned title is announced the moment it's earned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Titles = require(ReplicatedStorage.Shared.Titles)
local DataService = require(script.Parent.DataService)

local TitleService = {}

local titlesRemote = Remotes.Event("TitlesUpdated")
local notifyRemote = Remotes.Event("Notify")
local soundRemote = Remotes.Event("Sound")
local known: { [Player]: { [string]: boolean } } = {} -- the titles each player has been told about

local function earned(data: any): { [string]: boolean }
	local list = {}
	for _, t in Titles.List do
		if t.Earned(data) then
			list[t.Id] = true
		end
	end
	return list
end

-- Sends the player their titles, and announces any new one. `quiet` on joining: what they had is no news.
function TitleService.Refresh(player: Player, quiet: boolean?)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local now = earned(data)
	local before = known[player]
	local changed = before == nil
	for id in now do
		if before and not before[id] then
			changed = true
			if not quiet then
				local t = Titles.Get(id) :: Titles.Title
				notifyRemote:FireClient(player, `New title earned: "{t.Name}"! Wear it from your panel (top left).`)
				soundRemote:FireClient(player, "LevelUp")
			end
		end
	end
	known[player] = now
	if not changed then
		return
	end
	if not now[data.Title or ""] then
		data.Title = "Adventurer"
	end
	player:SetAttribute("Title", data.Title)
	titlesRemote:FireClient(player, { Earned = now, Wearing = data.Title })
end

function TitleService.OnKill(player: Player, enemyName: string)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	data.Kills = data.Kills or {}
	data.Kills[enemyName] = (data.Kills[enemyName] or 0) + 1
	TitleService.Refresh(player)
end

function TitleService.OnDps(player: Player, dps: number)
	local data = DataService.GetData(player)
	if not data or dps <= (data.BestDps or 0) then
		return
	end
	data.BestDps = math.floor(dps)
	TitleService.Refresh(player)
end

-- The tag over a player's head: their title on top (in its color), their rank under it.
local function tag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RankTag"
	gui.Size = UDim2.fromOffset(240, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 60
	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, 0, 0, 20)
	titleText.BackgroundTransparency = 1
	titleText.Font = Enum.Font.Fondamento
	titleText.TextSize = 19
	titleText.TextStrokeTransparency = 0.3
	titleText.Parent = gui
	local rankText = Instance.new("TextLabel")
	rankText.Position = UDim2.fromOffset(0, 20)
	rankText.Size = UDim2.new(1, 0, 0, 18)
	rankText.BackgroundTransparency = 1
	rankText.Font = Enum.Font.Fondamento
	rankText.TextSize = 15
	rankText.TextStrokeTransparency = 0.4
	rankText.Parent = gui
	local function refresh()
		local title = Titles.Get(player:GetAttribute("Title") :: string?)
		titleText.Text = if title then title.Name else "Adventurer"
		titleText.TextColor3 = if title then title.Color else Color3.fromRGB(226, 214, 196)
		local label = (player:GetAttribute("GuildRank") :: string?) or "Copper I"
		local founder = player:GetAttribute("Founder") :: number?
		rankText.Text = (if player:GetAttribute("VIP") then "VIP  ·  " else "") .. label .. (if founder then `  ·  Founder #{founder}` else "")
		rankText.TextColor3 = Quests.ColorOf(string.split(label, " ")[1])
	end
	refresh()
	for _, name in { "Title", "GuildRank", "Founder", "VIP" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	gui.Parent = head
end

function TitleService.Start()
	DataService.OnLoaded(function(player, _data)
		TitleService.Refresh(player, true)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			tag(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		if player.Character then
			task.spawn(tag, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			tag(player, character)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		known[player] = nil
	end)
	Remotes.Event("TitleChoose").OnServerEvent:Connect(function(player, id: any)
		local data = DataService.GetData(player)
		local t = type(id) == "string" and Titles.Get(id)
		if not data or not t or not t.Earned(data) then
			return
		end
		data.Title = id
		player:SetAttribute("Title", id)
		titlesRemote:FireClient(player, { Earned = earned(data), Wearing = id })
	end)
	-- every so often: titles earned elsewhere (a level, a daily streak, a floor) are noticed
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				TitleService.Refresh(player)
			end
		end
	end)
end

return TitleService
