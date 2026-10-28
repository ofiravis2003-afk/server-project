--!strict
-- The Titles window (opened from the panel top-left): every title, the earned ones bright with a Wear button,
-- the others dim with how to earn them. The one worn shows over the player's head (TitleService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TitleList = require(ReplicatedStorage.Shared.Titles)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local GOLD = Color3.fromRGB(240, 190, 90)
local DIM = Color3.fromRGB(120, 112, 104)

local Titles = {}

local state: { Earned: { [string]: boolean }, Wearing: string } = { Earned = { Adventurer = true }, Wearing = "Adventurer" }
local window: Frame? = nil
local list: ScrollingFrame? = nil
local onChange: { (string) -> () } = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function redraw()
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, t in TitleList.List do
		local has = state.Earned[t.Id] == true
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 52)
		row.BackgroundColor3 = if t.Id == state.Wearing then Color3.fromRGB(56, 42, 26) else Color3.fromRGB(36, 30, 30)
		row.Parent = list
		corner(row, 6)
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 4)
		name.Size = UDim2.new(1, -110, 0, 24)
		name.FontFace = Fonts.Title
		name.TextSize = 20
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = if has then t.Color else DIM
		name.Text = t.Name
		name.Parent = row
		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.Position = UDim2.fromOffset(10, 28)
		hint.Size = UDim2.new(1, -110, 0, 18)
		hint.FontFace = Fonts.Text
		hint.TextSize = 13
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.TextColor3 = if has then Color3.fromRGB(210, 200, 186) else DIM
		hint.Text = t.Hint
		hint.TextTruncate = Enum.TextTruncate.AtEnd
		hint.Parent = row
		local action = Instance.new("TextButton")
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -8, 0.5, 0)
		action.Size = UDim2.fromOffset(88, 32)
		action.FontFace = Fonts.Body
		action.TextSize = 15
		action.Parent = row
		corner(action, 6)
		if t.Id == state.Wearing then
			action.Text = "Wearing"
			action.AutoButtonColor = false
			action.BackgroundColor3 = Color3.fromRGB(70, 56, 30)
			action.TextColor3 = GOLD
		elseif has then
			action.Text = "Wear"
			action.BackgroundColor3 = Color3.fromRGB(150, 100, 40)
			action.TextColor3 = Color3.new(1, 1, 1)
			action.Activated:Connect(function()
				Remotes.Event("TitleChoose"):FireServer(t.Id)
			end)
		else
			action.Text = "Locked"
			action.AutoButtonColor = false
			action.BackgroundColor3 = Color3.fromRGB(44, 40, 40)
			action.TextColor3 = DIM
		end
	end
end

function Titles.Toggle()
	if window then
		window.Visible = not window.Visible
		if window.Visible then
			redraw()
		end
	end
end

-- Calls back with the worn title's name whenever it changes (the panel's caption).
function Titles.OnWearing(callback: (string) -> ())
	table.insert(onChange, callback)
	local t = TitleList.Get(state.Wearing)
	callback(if t then t.Name else "Adventurer")
end

function Titles.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Titles"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0, 460, 0.7, 0)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.05
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 10)
	local edge = Instance.new("UIStroke")
	edge.Color = EDGE
	edge.Thickness = 1.5
	edge.Parent = frame
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(460, 560)
	size.Parent = frame
	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(16, 10)
	heading.Size = UDim2.new(1, -60, 0, 32)
	heading.FontFace = Fonts.Title
	heading.TextSize = 26
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = GOLD
	heading.Text = "Titles"
	heading.Parent = frame
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = Color3.fromRGB(60, 40, 36)
	close.FontFace = Fonts.Body
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = frame
	corner(close, 6)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(12, 52)
	scroll.Size = UDim2.new(1, -24, 1, -64)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	window = frame
	list = scroll
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("TitlesUpdated").OnClientEvent:Connect(function(update: any)
		if type(update) ~= "table" then
			return
		end
		state.Earned = update.Earned or state.Earned
		state.Wearing = update.Wearing or state.Wearing
		local t = TitleList.Get(state.Wearing)
		for _, callback in onChange do
			callback(if t then t.Name else "Adventurer")
		end
		if frame.Visible then
			redraw()
		end
	end)
end

return Titles
