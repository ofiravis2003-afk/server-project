--!strict
-- The Guild's quest board (also a townsperson's own requests, like Old Pip's or Seraphine's): the player's rank and rank points at the top, then every quest that isn't locked:
-- its title, what to do, progress (12 / 20), the reward, and Accept / Turn in / Abandon. Done quests show a
-- tick. The server closes it when the player walks away from the Guild.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialogues = require(ReplicatedStorage.Shared.Dialogues)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Items = require(ReplicatedStorage.Shared.Items)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local GOOD = Color3.fromRGB(110, 220, 120)
local ROW = Color3.fromRGB(36, 30, 30)

type Entry = { Id: string, State: string, Progress: number }
type Snapshot = { Quests: { Entry }, Points: number }

local QuestBoard = {}

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function goalText(quest: Quests.Quest): string
	if quest.Kind == "Kill" then
		return `Slay {quest.Count} {quest.Target}{if quest.Count > 1 then "s" else ""}`
	elseif quest.Kind == "Collect" then
		local def = Items.Defs[quest.Target :: string]
		return `Bring {quest.Count} {def and def.DisplayName or quest.Target}`
	elseif quest.Kind == "Lore" then
		return if quest.Count == 1 then "Find a page of Ilvane's journal" else `Find {quest.Count} pages of Ilvane's journal`
	end
	return `Reach floor {quest.Count}`
end

function QuestBoard.Start()
	local player = Players.LocalPlayer
	local action = Remotes.Event("QuestAction")
	local snapshot: Snapshot = { Quests = {}, Points = 0 }
	local giver = "Aldric"

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestBoard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(560, 500)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = panel
	local s = Instance.new("UIStroke")
	s.Color = EDGE
	s.Thickness = 2
	s.Parent = panel

	local title = label(panel, Fonts.Title, 26, GOLD)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -60, 0, 30)
	title.Text = "Guild Quests"
	local rank = label(panel, Fonts.Body, 15, TEXT)
	rank.Position = UDim2.fromOffset(16, 42)
	rank.Size = UDim2.new(1, -32, 0, 20)
	rank.RichText = true

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
	close.FontFace = Fonts.Title
	close.TextSize = 18
	close.TextColor3 = TEXT
	close.Text = "X"
	close.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = close
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 70)
	list.Size = UDim2.new(1, -24, 1, -82)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function button(parent: Instance, text: string, color: Color3, x: number, onClick: () -> ())
		local b = Instance.new("TextButton")
		b.Name = text:gsub(" ", "")
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, x, 1, -8)
		b.Size = UDim2.fromOffset(104, 32)
		b.BackgroundColor3 = color
		b.FontFace = Fonts.Title
		b.TextSize = 16
		b.TextColor3 = TEXT
		b.Text = text
		b.Parent = parent
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = b
		b.Activated:Connect(onClick)
	end

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local standing = Quests.Standing(snapshot.Points)
		rank.Text = `Rank: <font color="#{standing.Color:ToHex()}"><b>{standing.Label}</b></font>`
			.. (if standing.Top then "   ·   the highest rank" else `   ·   {standing.Into} / {standing.Need} to the next tier`)
		local order = { Active = 1, Open = 2, Done = 3 }
		local shown = {}
		for _, e in snapshot.Quests do
			if e.State ~= "Locked" and Quests.GiverOf(Quests.ById[e.Id]) == giver then
				table.insert(shown, e)
			end
		end
		table.sort(shown, function(a, b)
			return (order[a.State] or 9) < (order[b.State] or 9)
		end)
		for i, e in shown do
			local quest = Quests.ById[e.Id]
			local row = Instance.new("Frame")
			row.Name = e.Id
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -8, 0, 96)
			row.BackgroundColor3 = ROW
			row.BackgroundTransparency = if e.State == "Done" then 0.4 else 0
			row.Parent = list
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 8)
			rc.Parent = row
			local name = label(row, Fonts.Title, 18, if e.State == "Done" then GOOD else GOLD)
			name.Position = UDim2.fromOffset(12, 6)
			name.Size = UDim2.new(1, -24, 0, 22)
			name.Text = (if e.State == "Done" then "✓ " else "") .. quest.Title .. (if quest.Repeatable then "  (bounty)" else "")
			local about = label(row, Fonts.Body, 13, Color3.fromRGB(190, 180, 165))
			about.Position = UDim2.fromOffset(12, 28)
			about.Size = UDim2.new(1, -24, 0, 32)
			about.Text = quest.Text
			local goal = label(row, Fonts.Body, 14, if e.Progress >= quest.Count then GOOD else TEXT)
			goal.Position = UDim2.fromOffset(12, 62)
			goal.Size = UDim2.new(1, -250, 0, 28)
			goal.Text = if e.State == "Open"
				then `{goalText(quest)}   ·   {quest.Gold} gold, {quest.XP} XP, {quest.Points} rank points`
				else `{goalText(quest)}: {e.Progress} / {quest.Count}`
			if e.State == "Open" then
				button(row, "Accept", Color3.fromRGB(40, 70, 45), -10, function()
					action:FireServer("Accept", e.Id)
				end)
			elseif e.State == "Active" then
				if e.Progress >= quest.Count then
					button(row, "Turn in", Color3.fromRGB(150, 100, 30), -10, function()
						action:FireServer("TurnIn", e.Id)
					end)
				end
				button(row, "Abandon", Color3.fromRGB(70, 40, 40), -122, function()
					action:FireServer("Abandon", e.Id)
				end)
			end
		end
	end

	Remotes.Event("QuestsUpdated").OnClientEvent:Connect(function(newSnapshot: Snapshot)
		snapshot = newSnapshot
		if gui.Enabled then
			redraw()
		end
	end)
	Remotes.Event("QuestBoardOpen").OnClientEvent:Connect(function(open: boolean?, who: string?)
		if open == false then
			gui.Enabled = false
			return
		end
		giver = if type(who) == "string" then who else "Aldric"
		local person = Dialogues[giver]
		title.Text = if giver == "Aldric" or not person then "Guild Quests" else `{person.Name}'s Requests`
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1.3, (screen.Y - 90) / panel.Size.Y.Offset, (screen.X - 24) / panel.Size.X.Offset)
		gui.Enabled = true
		redraw()
	end)
end

return QuestBoard
