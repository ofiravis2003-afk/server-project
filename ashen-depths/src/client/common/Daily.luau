--!strict
-- The daily gift and tasks on screen (DailyService on the server):
--   the day's first visit: a card with the 7-day ladder (days already won lit, today's gift shown, what
--   tomorrow brings), until closed
--   always: today's three tasks with their progress, on the right side of the screen (folds to one line)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Daily = require(ReplicatedStorage.Shared.Daily)
local Device = require(ReplicatedStorage.Shared.Device)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local DONE = Color3.fromRGB(110, 220, 120)
local DIM = Color3.fromRGB(150, 140, 130)

type Saved = { Id: string, Progress: number, Done: boolean }
type State = { Streak: number, Tasks: { Saved }, Gift: number? }

local DailyUi = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Color = color or EDGE
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

function DailyUi.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Daily"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- the tracker: today's tasks, on the right
	local tracker = Instance.new("TextButton")
	tracker.Name = "Tasks"
	tracker.AutoButtonColor = false
	tracker.Text = ""
	tracker.AnchorPoint = Vector2.new(1, 0)
	tracker.Position = UDim2.new(1, -12, 0, if Device.Touch() then 64 else 12)
	tracker.Size = UDim2.fromOffset(250, 0)
	tracker.AutomaticSize = Enum.AutomaticSize.Y
	tracker.BackgroundColor3 = PANEL
	tracker.BackgroundTransparency = 0.25
	tracker.Visible = false
	tracker.Parent = gui
	corner(tracker, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = tracker
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 2)
	stack.Parent = tracker
	local folded = false

	local state: State? = nil
	local function drawTracker()
		for _, child in tracker:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local s = state
		tracker.Visible = s ~= nil and #s.Tasks > 0
		if not s then
			return
		end
		local done = 0
		for _, saved in s.Tasks do
			if saved.Done then
				done += 1
			end
		end
		local head = label(tracker, Fonts.Title, 17, GOLD)
		head.Size = UDim2.new(1, 0, 0, 20)
		head.Text = `Daily tasks  {done}/{#s.Tasks}` .. (if folded then "  (show)" else "")
		if folded then
			return
		end
		for i, saved in s.Tasks do
			local task = Daily.ById[saved.Id]
			if task then
				local line = label(tracker, Fonts.Body, 14, if saved.Done then DONE else TEXT)
				line.LayoutOrder = i
				line.Size = UDim2.new(1, 0, 0, 18)
				line.TextTruncate = Enum.TextTruncate.AtEnd
				line.Text = if saved.Done then `✓ {task.Text}` else `{task.Text}  {saved.Progress}/{task.Count}`
			end
		end
	end
	tracker.Activated:Connect(function()
		folded = not folded
		drawTracker()
	end)

	-- the day's gift: a card with the ladder
	local function showGift(s: State)
		local step = s.Gift :: number
		local card = Instance.new("Frame")
		card.Name = "Gift"
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.fromOffset(560, 300)
		card.BackgroundColor3 = PANEL
		card.BackgroundTransparency = 0.03
		card.Parent = gui
		corner(card, 12)
		stroke(card)
		local fit = Instance.new("UIScale")
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1.2, (screen.X - 24) / 560, (screen.Y - 40) / 300)
		fit.Parent = card
		local title = label(card, Fonts.Title, 30, GOLD)
		title.Position = UDim2.fromOffset(0, 14)
		title.Size = UDim2.new(1, 0, 0, 34)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Text = `Day {s.Streak} in a row!`
		local sub = label(card, Fonts.Body, 17, TEXT)
		sub.Position = UDim2.fromOffset(0, 52)
		sub.Size = UDim2.new(1, 0, 0, 22)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		sub.Text = `Today's gift: {Daily.Rewards[step].Text}`
		-- the ladder: seven boxes, won ones lit, today's glowing
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(20, 90)
		row.Size = UDim2.new(1, -40, 0, 110)
		row.Parent = card
		local grid = Instance.new("UIListLayout")
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.Padding = UDim.new(0, 8)
		grid.Parent = row
		for day = 1, #Daily.Rewards do
			local box = Instance.new("Frame")
			box.Size = UDim2.new(1 / #Daily.Rewards, -7, 1, 0)
			box.BackgroundColor3 = if day == step then Color3.fromRGB(90, 55, 20) elseif day < step then Color3.fromRGB(45, 60, 40) else Color3.fromRGB(36, 30, 32)
			box.Parent = row
			corner(box, 8)
			stroke(box, if day == step then GOLD elseif day == #Daily.Rewards then Color3.fromRGB(170, 80, 255) else EDGE)
			local n = label(box, Fonts.Title, 16, if day <= step then GOLD else DIM)
			n.Size = UDim2.new(1, 0, 0, 24)
			n.Position = UDim2.fromOffset(0, 4)
			n.TextXAlignment = Enum.TextXAlignment.Center
			n.Text = if day < step then "✓" else `Day {day}`
			local what = label(box, Fonts.Body, 12, if day <= step then TEXT else DIM)
			what.Position = UDim2.fromOffset(4, 30)
			what.Size = UDim2.new(1, -8, 1, -34)
			what.TextWrapped = true
			what.TextXAlignment = Enum.TextXAlignment.Center
			what.TextYAlignment = Enum.TextYAlignment.Top
			what.Text = Daily.Rewards[day].Text
		end
		local tomorrow = label(card, Fonts.Body, 14, DIM)
		tomorrow.Position = UDim2.fromOffset(0, 210)
		tomorrow.Size = UDim2.new(1, 0, 0, 20)
		tomorrow.TextXAlignment = Enum.TextXAlignment.Center
		local nextStep = step % #Daily.Rewards + 1
		tomorrow.Text = `Come back tomorrow for: {Daily.Rewards[nextStep].Text}  (miss a day and it starts over)`
		local ok = Instance.new("TextButton")
		ok.AnchorPoint = Vector2.new(0.5, 1)
		ok.Position = UDim2.new(0.5, 0, 1, -14)
		ok.Size = UDim2.fromOffset(160, 40)
		ok.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
		ok.FontFace = Fonts.Title
		ok.TextSize = 20
		ok.TextColor3 = TEXT
		ok.Text = "Claim"
		ok.Parent = card
		corner(ok, 8)
		stroke(ok)
		ok.Activated:Connect(function()
			TweenService:Create(fit, TweenInfo.new(0.2), { Scale = 0 }):Play()
			task.delay(0.22, function()
				card:Destroy()
			end)
		end)
		fit.Scale *= 0.8
		TweenService:Create(fit, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fit.Scale / 0.8 }):Play()
	end

	Remotes.Event("DailyUpdated").OnClientEvent:Connect(function(newState: any)
		if type(newState) ~= "table" then
			return
		end
		state = newState
		drawTracker()
		if type(newState.Gift) == "number" then
			showGift(newState)
		end
	end)
end

return DailyUi
