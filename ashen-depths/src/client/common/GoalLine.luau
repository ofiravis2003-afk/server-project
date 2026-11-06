--!strict
-- The next goal (the player's "Goal" attribute, GoalService on the server): a small panel at the top right,
-- above the daily tasks. When a goal is reached it says so for a moment, then shows the next one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Device = require(ReplicatedStorage.Shared.Device)

local PHONE_SCALE = 0.65 -- (a phone's screen is crowded: the panel a size down, against the right edge)

local PANEL = Color3.fromRGB(22, 18, 20)
local GOLD = Color3.fromRGB(240, 190, 90)
local TEXT = Color3.fromRGB(230, 222, 208)
local DONE = Color3.fromRGB(110, 220, 120)

local GoalLine = {}

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

-- "what\nwhere" (shared/Goals): the "where" a shade dimmer under it
local function format(mark: string, text: string): string
	local what, where = string.match(text, "^(.-)\n(.*)$")
	if what and where then
		return `{mark} {what}\n<font color="#a39482">{where}</font>`
	end
	return `{mark} {text}`
end

function GoalLine.Start()
	local player = Players.LocalPlayer
	local column = player:WaitForChild("PlayerGui"):WaitForChild("Daily"):WaitForChild("Column")

	local panel = Instance.new("Frame")
	panel.Name = "Goal"
	panel.LayoutOrder = 1
	panel.Size = UDim2.fromOffset(250, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.25
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 1.5
	edge.Transparency = 1
	edge.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = panel
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 2)
	stack.Parent = panel

	local head = label(panel, Fonts.Title, 17, GOLD)
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, 20)
	head.Text = "Next goal"
	local line = label(panel, Fonts.Body, 14, TEXT)
	line.LayoutOrder = 2
	line.Size = UDim2.new(1, 0, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.TextWrapped = true
	line.RichText = true

	if Device.Touch() then
		local scale = Instance.new("UIScale")
		scale.Scale = PHONE_SCALE
		scale.Parent = panel
	end
	panel.Parent = column

	local shown: string? = nil
	local generation = 0
	local function update()
		local goal = player:GetAttribute("Goal")
		local text = if type(goal) == "string" then goal else nil
		if text == shown then
			return
		end
		local before = shown
		shown = text
		generation += 1
		local mine = generation
		if not text then
			panel.Visible = false
			return
		end
		panel.Visible = true
		if not before then
			line.Text = format("◆", text)
			return
		end
		-- the old goal is reached: say so, glow, then the new one
		head.Text = "Goal reached!"
		head.TextColor3 = DONE
		line.Text = format("✓", before)
		edge.Transparency = 0
		TweenService:Create(edge, TweenInfo.new(3), { Transparency = 1 }):Play()
		task.delay(3, function()
			if generation ~= mine then
				return
			end
			head.Text = "Next goal"
			head.TextColor3 = GOLD
			line.Text = format("◆", text)
		end)
	end
	player:GetAttributeChangedSignal("Goal"):Connect(update)
	update()
end

return GoalLine
