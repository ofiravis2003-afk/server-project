--!strict
-- The floor picker: opened at the waystone in floor 1's entrance. Every floor from 1 to the deepest one the
-- player has reached can be chosen (to go back and get stronger, or to go straight down); deeper floors are
-- locked. Boss and Guardian floors are marked. The server checks the choice again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local OPEN = Color3.fromRGB(46, 38, 34)
local LOCKED = Color3.fromRGB(28, 26, 26)
local BOSS = Color3.fromRGB(150, 40, 40)
local GUARD = Color3.fromRGB(150, 110, 40)
local COLUMNS = 5
local CELL = Vector2.new(96, 64)

type Offer = { Unlocked: number, Max: number, Marks: { [string]: string }, Hollow: { number }? }

local FloorPicker = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
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
	l.Parent = parent
	return l
end

function FloorPicker.Start()
	local player = Players.LocalPlayer
	local choose = Remotes.Event("ChooseFloor")

	local gui = Instance.new("ScreenGui")
	gui.Name = "FloorPicker"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local rows = 3
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(COLUMNS * (CELL.X + 8) + 28, rows * (CELL.Y + 8) + 108)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel, EDGE, 2)
	local fit = Instance.new("UIScale")
	fit.Parent = panel

	local title = label(panel, Fonts.Title, 26, GOLD)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -60, 0, 32)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Choose a floor"
	local hint = label(panel, Fonts.Body, 14, Color3.fromRGB(190, 180, 165))
	hint.Position = UDim2.fromOffset(14, 40)
	hint.Size = UDim2.new(1, -28, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "Go back to grow stronger, or straight down to the deepest floor you have reached."

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
	corner(close, 6)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	-- (it scrolls once The Hollow's checkpoints don't fit any more)
	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(14, 68)
	grid.Size = UDim2.new(1, -20, 1, -80)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local function show(offer: Offer)
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for floor = 1, offer.Max do
			local open = floor <= offer.Unlocked
			local mark = offer.Marks[tostring(floor)]
			local cell = Instance.new("TextButton")
			cell.Name = `Floor{floor}`
			cell.LayoutOrder = floor
			cell.Text = ""
			cell.AutoButtonColor = open
			cell.BackgroundColor3 = if open then OPEN else LOCKED
			cell.Parent = grid
			corner(cell, 8)
			stroke(cell, if mark == "Boss" then BOSS elseif mark == "Guardians" then GUARD elseif open then EDGE else Color3.fromRGB(50, 46, 44), if mark then 2.5 else 1.5)
			local number = label(cell, Fonts.Title, 26, if open then TEXT else Color3.fromRGB(90, 86, 82))
			number.Size = UDim2.new(1, 0, 0, 34)
			number.Position = UDim2.fromOffset(0, 6)
			number.Text = tostring(floor)
			local under = label(cell, Fonts.Body, 13, if mark == "Boss" then Color3.fromRGB(235, 110, 100) elseif mark == "Guardians" then Color3.fromRGB(235, 190, 110) else Color3.fromRGB(150, 140, 130))
			under.Size = UDim2.new(1, 0, 0, 16)
			under.Position = UDim2.fromOffset(0, 40)
			under.Text = if not open then "Locked" elseif mark then mark elseif floor == offer.Unlocked then "Deepest" else ""
			if open then
				cell.Activated:Connect(function()
					gui.Enabled = false
					choose:FireServer(floor)
				end)
			end
		end
		-- The Hollow: the checkpoints earned there (16, 21, 26, ...)
		for i, floor in offer.Hollow or {} do
			local cell = Instance.new("TextButton")
			cell.Name = `Floor{floor}`
			cell.LayoutOrder = offer.Max + i
			cell.Text = ""
			cell.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
			cell.Parent = grid
			corner(cell, 8)
			stroke(cell, Color3.fromRGB(150, 100, 220), 2.5)
			local number = label(cell, Fonts.Title, 26, TEXT)
			number.Size = UDim2.new(1, 0, 0, 34)
			number.Position = UDim2.fromOffset(0, 6)
			number.Text = tostring(floor)
			local under = label(cell, Fonts.Body, 13, Color3.fromRGB(190, 150, 240))
			under.Size = UDim2.new(1, 0, 0, 16)
			under.Position = UDim2.fromOffset(0, 40)
			under.Text = "The Hollow"
			cell.Activated:Connect(function()
				gui.Enabled = false
				choose:FireServer(floor)
			end)
		end
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1, (screen.X - 24) / panel.Size.X.Offset, (screen.Y - 90) / panel.Size.Y.Offset)
		gui.Enabled = true
	end

	Remotes.Event("FloorPicker").OnClientEvent:Connect(show)
end

return FloorPicker
