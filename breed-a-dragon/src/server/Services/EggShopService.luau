--!strict
-- The Egg Shop: one pedestal per egg, behind the spawn point.
-- Each pedestal shows the egg, its price and the exact odds of every rarity
-- (Roblox requires showing odds before buying a random item). Hold E / tap to buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggBuilder = require(ReplicatedStorage.Shared.EggBuilder)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Eggs = require(ReplicatedStorage.Shared.Eggs)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EggService = require(script.Parent.EggService)
local Ground = require(script.Parent.Parent.Util.Ground)

local SHOP_DISTANCE = 40 -- studs behind the spawn point
local PEDESTAL_SPACING = 14
local PEDESTAL_HEIGHT = 3

local EggShopService = {}

local notifyRemote = Remotes.Event("Notify")

local function addText(parent: Instance, text: string, color: Color3, height: number, order: number, font: Font?)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.FontFace = font or Fonts.Body
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.LayoutOrder = order
	label.Parent = parent
end

local function createSign(egg: Eggs.Egg, parent: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggSign"
	billboard.Size = UDim2.fromOffset(190, 175)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, PEDESTAL_HEIGHT / 2 + 7.5, 0)
	billboard.MaxDistance = 70
	billboard.Parent = parent

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = billboard

	addText(billboard, egg.Name, Color3.new(1, 1, 1), 34, 1, Fonts.Title)
	addText(billboard, `{Config.Currency.Icon} {egg.Price}`, Color3.fromRGB(255, 190, 80), 28, 2)
	local odds = Eggs.GetOdds(egg.Id)
	for _, tier in Rarity.Tiers do
		addText(billboard, `{tier.Name}  {Eggs.FormatChance(odds[tier.Name])}`, tier.Color, 22, 2 + tier.Order)
	end
end

local function createPedestal(egg: Eggs.Egg, position: Vector3, parent: Instance)
	local pedestal = Instance.new("Part")
	pedestal.Name = egg.Id .. "Pedestal"
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(PEDESTAL_HEIGHT, 5, 5)
	-- Cylinders run along X; stand it upright.
	pedestal.CFrame = CFrame.new(position + Vector3.new(0, PEDESTAL_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Anchored = true
	pedestal.Material = Enum.Material.Slate
	pedestal.Color = Color3.fromRGB(110, 100, 115)
	pedestal.Parent = parent

	local eggModel = EggBuilder.Build(egg.Id)
	eggModel:PivotTo(CFrame.new(position + Vector3.new(0, PEDESTAL_HEIGHT, 0)))
	eggModel.Parent = parent

	createSign(egg, pedestal)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = `{egg.Name} ({egg.Price} {Config.Currency.Name})`
	prompt.HoldDuration = 0.4 -- a short hold so nobody buys by accident
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal

	prompt.Triggered:Connect(function(player)
		local _, message = EggService.Buy(player, egg.Id)
		notifyRemote:FireClient(player, message)
	end)
end

function EggShopService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "EggShop"
	folder.Parent = workspace

	local center = Ground.GetSpawnCenter() + Vector3.new(0, 0, SHOP_DISTANCE)
	local forSale = {}
	for _, egg in Eggs.List do
		if not egg.Hidden then
			table.insert(forSale, egg)
		end
	end
	for i, egg in forSale do
		local x = (i - (#forSale + 1) / 2) * PEDESTAL_SPACING
		createPedestal(egg, center + Vector3.new(x, 0, 0), folder)
	end
end

return EggShopService
