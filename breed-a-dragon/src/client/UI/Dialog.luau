--!strict
-- Elder Ember's speech box above the nests bar. Lines appear letter by letter;
-- click / tap the box (or "Next") to go on. New lines that arrive while he is talking wait their turn.

local Players = game:GetService("Players")

local Fonts = require(game:GetService("ReplicatedStorage").Shared.Fonts)

local ORANGE = Color3.fromRGB(255, 160, 60)
local DARK = Color3.fromRGB(25, 20, 30)
local LETTERS_PER_SECOND = 55

local Dialog = {}

local screenGui: ScreenGui
local box: TextButton
local textLabel: TextLabel
local nextLabel: TextLabel
local queue: { string } = {}
local showing = false
local typing = false
local skipTyping = false
local advance: BindableEvent

local function build()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Dialog"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5

	box = Instance.new("TextButton")
	box.Name = "Box"
	box.AutoButtonColor = false
	box.Text = ""
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -128)
	box.Size = UDim2.new(0.92, 0, 0, 118)
	box.BackgroundColor3 = DARK
	box.BackgroundTransparency = 0.1
	box.Visible = false
	box.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = ORANGE
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 118)
	limit.Parent = box

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(16, 8)
	name.Size = UDim2.new(1, -32, 0, 24)
	name.FontFace = Fonts.Title
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = ORANGE
	name.Text = "🐉 Elder Ember"
	name.Parent = box

	textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromOffset(16, 36)
	textLabel.Size = UDim2.new(1, -32, 1, -62)
	textLabel.FontFace = Fonts.Text
	textLabel.TextSize = 18
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Parent = box

	nextLabel = Instance.new("TextLabel")
	nextLabel.BackgroundTransparency = 1
	nextLabel.AnchorPoint = Vector2.new(1, 1)
	nextLabel.Position = UDim2.new(1, -14, 1, -6)
	nextLabel.Size = UDim2.fromOffset(120, 22)
	nextLabel.FontFace = Fonts.Body
	nextLabel.TextScaled = true
	nextLabel.TextXAlignment = Enum.TextXAlignment.Right
	nextLabel.TextColor3 = ORANGE
	nextLabel.Parent = box

	advance = Instance.new("BindableEvent")
	box.Activated:Connect(function()
		if typing then
			skipTyping = true
		else
			advance:Fire()
		end
	end)

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function run()
	showing = true
	box.Visible = true
	while #queue > 0 do
		local line = table.remove(queue, 1) :: string
		nextLabel.Text = if #queue > 0 then "Next ▶" else "Close ✕"
		textLabel.Text = line
		textLabel.MaxVisibleGraphemes = 0
		typing, skipTyping = true, false
		local total = utf8.len(line) or #line
		local shown = 0
		while shown < total and not skipTyping do
			shown += math.max(1, math.floor(task.wait() * LETTERS_PER_SECOND))
			textLabel.MaxVisibleGraphemes = shown
		end
		textLabel.MaxVisibleGraphemes = -1
		typing = false
		advance.Event:Wait()
	end
	box.Visible = false
	showing = false
end

-- Elder Ember says these lines, one after another.
function Dialog.Say(lines: { string })
	for _, line in lines do
		if type(line) == "string" then
			table.insert(queue, line)
		end
	end
	if not showing and #queue > 0 then
		task.spawn(run)
	end
end

function Dialog.Start()
	build()
end

return Dialog
