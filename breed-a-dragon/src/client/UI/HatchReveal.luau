--!strict
-- The hatch moment: the egg wobbles, cracks in a white flash, and the new dragon
-- turns in front of the player, flapping its wings, with its name and rarity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DragonAnimator = require(ReplicatedStorage.Shared.DragonAnimator)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local EggBuilder = require(ReplicatedStorage.Shared.EggBuilder)
local Genes = require(ReplicatedStorage.Shared.Genes)
local Rarity = require(ReplicatedStorage.Shared.Rarity)

local WOBBLE_TIME = 1.4
local SPIN_SPEED = 0.6 -- radians per second

local HatchReveal = {}

local function newLabel(
	parent: Instance,
	text: string,
	y: number,
	height: number,
	color: Color3,
	font: Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.5, y)
	label.Size = UDim2.new(0.9, 0, 0, height)
	label.BackgroundTransparency = 1
	label.FontFace = font or Fonts.Body
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = parent
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, height)
	limit.Parent = label
	return label
end

-- Points the camera so the whole model fits, seen from the front-left and a little above.
local function frameModel(camera: Camera, model: Model)
	local box, size = model:GetBoundingBox()
	local reach = math.sqrt(math.max(size.X, size.Z) ^ 2 + size.Y ^ 2) / 2
	local distance = reach / math.tan(math.rad(camera.FieldOfView / 2)) * 1.2
	local center = box.Position
	local direction = Vector3.new(-0.55, 0.35, -1).Unit
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
end

export type Extras = {
	WorldFirst: boolean?, -- first in the whole world to get this dragon
	Mutated: { string }?, -- traits that mutated while breeding
	NewGenes: { string }?, -- "Trait.Id" keys that are new in the player's Dragon Index
}

-- "Wings.Feathered" -> "Feathered wings"
local function describeGene(key: string): string
	local trait, id = string.match(key, "^(%a+)%.(.+)$")
	if not trait or not id then
		return key
	end
	if trait == "Body" or trait == "Accent" then
		return `{id} {string.lower(trait)} colour`
	end
	return `{id} {string.lower(trait)}`
end

-- Shows the hatch animation for a dragon from `eggId`. Closes when the player presses the button.
function HatchReveal.Play(eggId: string, genes: Genes.DragonGenes, extras: Extras?)
	local info: Extras = extras or {}
	local rarity: Rarity.Tier = Genes.GetRarity(genes)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HatchReveal"
	screenGui.DisplayOrder = 10
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Active = true -- swallow clicks so nothing behind gets pressed
	backdrop.Parent = screenGui

	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.new(0.5, 0, 0.5, -40)
	viewport.Size = UDim2.fromOffset(420, 320)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(160, 160, 170)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	viewport.Parent = backdrop

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 5
	flash.Parent = backdrop

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- 1. The egg wobbles harder and harder.
	local egg = EggBuilder.Build(eggId)
	egg:PivotTo(CFrame.new())
	egg.Parent = viewport
	frameModel(camera, egg)

	local start = os.clock()
	while os.clock() - start < WOBBLE_TIME do
		local t = os.clock() - start
		local strength = t / WOBBLE_TIME
		egg:PivotTo(CFrame.Angles(0, 0, math.sin(t * 28) * math.rad(14) * strength))
		RunService.RenderStepped:Wait()
	end

	-- 2. Flash, and the dragon is there.
	flash.BackgroundTransparency = 0
	egg:Destroy()
	local dragon = DragonBuilder.Build(genes)
	dragon:PivotTo(CFrame.new())
	dragon.Parent = viewport
	frameModel(camera, dragon)
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()

	local rig = DragonAnimator.Rig(dragon)
	local spinStart = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - spinStart
		DragonAnimator.Apply(rig, CFrame.Angles(0, t * SPIN_SPEED, 0), t * DragonAnimator.FlapSpeed(0.4), 0.4)
	end)

	if info.WorldFirst then
		local banner = newLabel(backdrop, "🏆 WORLD FIRST! 🏆", -250, 50, Color3.fromRGB(255, 215, 60))
		TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Rotation = 2,
			TextStrokeTransparency = 0.8,
		}):Play()
	else
		newLabel(backdrop, "NEW DRAGON!", -240, 40, Color3.fromRGB(255, 200, 90))
	end
	newLabel(backdrop, Genes.GetName(genes), 125, 44, Color3.new(1, 1, 1), Fonts.Title)
	local rarityLabel = newLabel(backdrop, rarity.Name, 172, 34, rarity.Color)

	-- Mutation and new Index entries, one short line under the rarity.
	local notes = {}
	if info.Mutated and #info.Mutated > 0 then
		table.insert(notes, `🧬 Mutation: {table.concat(info.Mutated, ", ")}`)
	end
	if info.NewGenes and #info.NewGenes > 0 then
		local described = {}
		for i, key in info.NewGenes do
			if i > 3 then
				table.insert(described, `+{#info.NewGenes - 3} more`)
				break
			end
			table.insert(described, describeGene(key))
		end
		table.insert(notes, `📖 New: {table.concat(described, ", ")}`)
	end
	if #notes > 0 then
		newLabel(backdrop, table.concat(notes, "   "), 210, 26, Color3.fromRGB(200, 230, 255))
	end

	-- Epic and rarer: make the rarity pulse.
	if rarity.Order >= Rarity.Get("Epic").Order then
		TweenService:Create(
			rarityLabel,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ TextStrokeTransparency = 0.9, Rotation = 3 }
		):Play()
	end

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0.5, 245)
	button.Size = UDim2.fromOffset(200, 50)
	button.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
	button.FontFace = Fonts.Body
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "Awesome!"
	button.Parent = backdrop
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	button.Activated:Connect(function()
		spin:Disconnect()
		screenGui:Destroy()
	end)
end

return HatchReveal
