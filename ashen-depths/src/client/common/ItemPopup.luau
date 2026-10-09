--!strict
-- "New item!" popup: whenever the player gets an item, a card slides up from the bottom of the screen
-- with a slowly turning 3D view of it, its name in its rarity color, its rarity and its damage.
-- Several items in a row wait their turn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponBuilder = require(ReplicatedStorage.Shared.WeaponBuilder)

local SHOW_TIME = 3.5
local CARD_SIZE = UDim2.fromOffset(360, 120)
local SHOWN = UDim2.new(0.5, 0, 1, -150)
local HIDDEN = UDim2.new(0.5, 0, 1, 140)

local ItemPopup = {}

type Received = { Item: string, Rarity: string }

local queue: { Received } = {}
local showing = false

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.5
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function buildCard(gui: ScreenGui, received: Received): (Frame, () -> ())
	local def = Items.Defs[received.Item]
	local info = Rarity.Info[received.Rarity] or Rarity.Info.Common

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = HIDDEN
	card.Size = CARD_SIZE
	card.BackgroundColor3 = Color3.fromRGB(20, 16, 18)
	card.BackgroundTransparency = 0.08
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = info.Color
	stroke.Thickness = 2.5
	stroke.Parent = card
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(info.Color:Lerp(Color3.new(0, 0, 0), 0.75), Color3.fromRGB(20, 16, 18))
	glow.Rotation = 0
	glow.Parent = card

	-- A turning 3D view of the item
	local view = Instance.new("ViewportFrame")
	view.Position = UDim2.fromOffset(10, 10)
	view.Size = UDim2.fromOffset(100, 100)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(150, 150, 150)
	view.LightColor = Color3.fromRGB(255, 235, 210)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = card
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	local spin: RBXScriptConnection? = nil
	if def and def.Look then
		local tool = WeaponBuilder.Build(def.Look)
		local model = Instance.new("Model")
		for _, child in tool:GetChildren() do
			child.Parent = model
		end
		tool:Destroy()
		model.Parent = view
		local box, size = model:GetBoundingBox()
		local center = box.Position
		local distance = math.max(size.X, size.Y, size.Z) * 1.6 + 1
		local angle = 0
		spin = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 1.2
			camera.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(angle) * distance, distance * 0.25, math.cos(angle) * distance), center)
		end)
	end

	local header = label(card, Fonts.Title, 16, Color3.fromRGB(240, 220, 170))
	header.Position = UDim2.fromOffset(122, 10)
	header.Size = UDim2.fromOffset(228, 20)
	header.Text = "New item!"

	local name = label(card, Fonts.Title, 24, info.Color)
	name.Position = UDim2.fromOffset(122, 32)
	name.Size = UDim2.fromOffset(228, 30)
	name.TextScaled = true
	name.Text = if def then def.DisplayName else received.Item
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 24
	nameLimit.Parent = name

	local rarity = label(card, Fonts.Body, 15, info.Color)
	rarity.Position = UDim2.fromOffset(122, 64)
	rarity.Size = UDim2.fromOffset(228, 18)
	rarity.Text = if def and def.WeaponType then `{received.Rarity} {def.WeaponType}` else received.Rarity

	local stats = label(card, Fonts.Body, 14, Color3.fromRGB(220, 215, 205))
	stats.Position = UDim2.fromOffset(122, 86)
	stats.Size = UDim2.fromOffset(228, 18)
	local damage = Items.WeaponDamage(received.Item, received.Rarity, 0)
	local heal = Items.WeaponHeal(received.Item, received.Rarity, 0)
	stats.Text = if heal > 0
		then `Damage {math.floor(damage + 0.5)}   Heal {math.floor(heal + 0.5)}`
		else `Damage {math.floor(damage + 0.5)}`

	return card, function()
		if spin then
			spin:Disconnect()
		end
		card:Destroy()
	end
end

local function showNext(gui: ScreenGui)
	if showing then
		return
	end
	local received = table.remove(queue, 1)
	if not received then
		return
	end
	showing = true
	local card, cleanup = buildCard(gui, received)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN }):Play()
	task.delay(SHOW_TIME, function()
		local out = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN })
		out:Play()
		out.Completed:Wait()
		cleanup()
		showing = false
		showNext(gui)
	end)
end

function ItemPopup.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ItemPopup"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("ItemReceived").OnClientEvent:Connect(function(received: Received)
		table.insert(queue, received)
		showNext(gui)
	end)
end

return ItemPopup
