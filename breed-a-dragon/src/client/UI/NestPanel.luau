--!strict
-- The nests bar at the bottom of the screen: one slot per nest, showing the egg inside,
-- a countdown, and a "HATCH!" button when it's ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Eggs = require(ReplicatedStorage.Shared.Eggs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SLOT_SIZE = 96
local SLOT_GAP = 8
local DARK = Color3.fromRGB(25, 20, 30)
local READY = Color3.fromRGB(80, 220, 120)

type NestEgg = { Nest: number, Egg: string, HatchAt: number }
type Slot = { Frame: Frame, EggIcon: Frame, Title: TextLabel, Timer: TextLabel, Button: TextButton, Stroke: UIStroke }

local NestPanel = {}

local screenGui: ScreenGui
local row: Frame
local slots: { Slot } = {}
local eggsByNest: { [number]: NestEgg } = {}
local hatching: { [number]: boolean } = {}
local onHatchClicked: (nest: number) -> () = function() end

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function newLabel(parent: Instance, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = parent
	return label
end

local function createSlot(nest: number): Slot
	local frame = Instance.new("Frame")
	frame.Name = "Nest" .. nest
	frame.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	frame.BackgroundColor3 = DARK
	frame.BackgroundTransparency = 0.15
	frame.LayoutOrder = nest
	frame.Parent = row
	corner(frame, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(90, 80, 100)
	stroke.Parent = frame

	local eggIcon = Instance.new("Frame")
	eggIcon.AnchorPoint = Vector2.new(0.5, 0)
	eggIcon.Position = UDim2.new(0.5, 0, 0, 8)
	eggIcon.Size = UDim2.fromOffset(30, 38)
	eggIcon.Parent = frame
	corner(eggIcon, 15)

	local title = newLabel(frame, UDim2.new(0, 4, 0, 50), UDim2.new(1, -8, 0, 18))
	local timer = newLabel(frame, UDim2.new(0, 4, 0, 70), UDim2.new(1, -8, 0, 20))
	timer.TextColor3 = Color3.fromRGB(255, 190, 80)

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -6)
	button.Size = UDim2.new(1, -12, 0, 30)
	button.BackgroundColor3 = READY
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "HATCH!"
	button.Visible = false
	button.Parent = frame
	corner(button, 10)

	button.Activated:Connect(function()
		if hatching[nest] then
			return
		end
		hatching[nest] = true
		onHatchClicked(nest)
		hatching[nest] = nil
	end)

	return { Frame = frame, EggIcon = eggIcon, Title = title, Timer = timer, Button = button, Stroke = stroke }
end

local function refreshSlot(nest: number, slot: Slot)
	local entry = eggsByNest[nest]
	local egg = entry and Eggs.Get(entry.Egg)
	if not entry or not egg then
		slot.EggIcon.BackgroundColor3 = Color3.fromRGB(60, 55, 65)
		slot.EggIcon.BackgroundTransparency = 0.5
		slot.Title.Text = "Empty nest"
		slot.Timer.Text = "Buy an egg!"
		slot.Timer.TextColor3 = Color3.fromRGB(170, 160, 180)
		slot.Button.Visible = false
		slot.Stroke.Color = Color3.fromRGB(90, 80, 100)
		return
	end

	slot.EggIcon.BackgroundColor3 = egg.Color
	slot.EggIcon.BackgroundTransparency = 0
	slot.Title.Text = egg.Name
	local remaining = entry.HatchAt - workspace:GetServerTimeNow()
	local ready = remaining <= 0
	slot.Button.Visible = ready
	slot.Timer.Visible = not ready
	slot.Timer.Text = formatTime(remaining)
	slot.Timer.TextColor3 = Color3.fromRGB(255, 190, 80)
	slot.Stroke.Color = if ready then READY else Color3.fromRGB(90, 80, 100)
end

local function rebuild(nestCount: number)
	for _, slot in slots do
		slot.Frame:Destroy()
	end
	slots = {}
	for nest = 1, nestCount do
		slots[nest] = createSlot(nest)
	end
	row.Size = UDim2.fromOffset(nestCount * SLOT_SIZE + (nestCount - 1) * SLOT_GAP, SLOT_SIZE)
end

-- `callback(nest)` runs when the player presses HATCH on a ready egg.
function NestPanel.OnHatch(callback: (nest: number) -> ())
	onHatchClicked = callback
end

-- Plays a little bounce on a slot (used when a hatch is refused, etc.).
function NestPanel.Shake(nest: number)
	local slot = slots[nest]
	if not slot then
		return
	end
	local start = slot.Frame.Position
	local tween = TweenService:Create(
		slot.Frame,
		TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true),
		{
			Position = start + UDim2.fromOffset(6, 0),
		}
	)
	tween:Play()
end

function NestPanel.Start()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Nests"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	row = Instance.new("Frame")
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -16)
	row.BackgroundTransparency = 1
	row.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	Remotes.Event("NestsUpdated").OnClientEvent:Connect(function(state: { NestCount: number, Eggs: { NestEgg } })
		eggsByNest = {}
		for _, entry in state.Eggs do
			eggsByNest[entry.Nest] = entry
		end
		if #slots ~= state.NestCount then
			rebuild(state.NestCount)
		end
		for nest, slot in slots do
			refreshSlot(nest, slot)
		end
	end)

	-- Tick the countdowns.
	task.spawn(function()
		while true do
			for nest, slot in slots do
				refreshSlot(nest, slot)
			end
			task.wait(0.25)
		end
	end)
end

return NestPanel
