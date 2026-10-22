--!strict
-- A shopkeeper's window: their name and a line from them, what they sell (a 3D picture, the name in its
-- rarity's color, the price), Buy buttons, and "Sell from your bag" (the bag's button says Sell while a shop
-- is open). The server closes it when the player walks away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.Shared.Armor)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Parent.Common.Inventory)
local Upgrade = require(script.Parent.Upgrade)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local ROW = Color3.fromRGB(36, 30, 30)

type Offer = { Item: string, Rarity: string, Price: number }
type Shop = { Shop: string, Title: string, Line: string, Offers: { Offer } }

local Shop = {}

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
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.FontFace = Fonts.Title
	b.TextSize = 17
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	stroke(b, EDGE, 1.5)
	return b
end

local function picture(parent: Instance, offer: Offer)
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromOffset(52, 52)
	view.Position = UDim2.fromOffset(6, 4)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(215, 205, 195)
	view.LightColor = Color3.fromRGB(255, 235, 210)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = parent
	local model = ItemModels.Build(offer.Item, offer.Rarity)
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	local box, extents = model:GetBoundingBox()
	local distance = math.max(extents.X, extents.Y, extents.Z) * 1.45 + 0.5
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(distance * 0.55, distance * 0.3, -distance * 0.8), box.Position)
end

function Shop.Start()
	local player = Players.LocalPlayer
	local buyRemote = Remotes.Event("ShopBuy")
	local closeRemote = Remotes.Event("ShopClose")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, 0)
	panel.Size = UDim2.fromOffset(380, 470)
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
	local line = label(panel, Fonts.Body, 14, Color3.fromRGB(200, 190, 175))
	line.Position = UDim2.fromOffset(14, 40)
	line.Size = UDim2.new(1, -28, 0, 36)
	line.TextWrapped = true
	line.TextYAlignment = Enum.TextYAlignment.Top

	local close = button(panel, "X", Color3.fromRGB(60, 30, 30))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(32, 32)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 80)
	list.Size = UDim2.new(1, -24, 1, -140)
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

	local sell = button(panel, "Sell from your bag", Color3.fromRGB(80, 55, 25))
	sell.Position = UDim2.new(0, 12, 1, -50)
	sell.Size = UDim2.new(1, -24, 0, 38)
	-- Brakka also upgrades weapons
	local upgrade = button(panel, "Upgrade weapons", Color3.fromRGB(120, 70, 25))
	upgrade.Position = UDim2.new(0, 12, 1, -94)
	upgrade.Size = UDim2.new(1, -24, 0, 38)
	upgrade.Visible = false
	upgrade.Activated:Connect(function()
		Upgrade.Open()
	end)

	local function hide()
		gui.Enabled = false
	end
	close.Activated:Connect(function()
		hide()
		closeRemote:FireServer()
	end)
	sell.Activated:Connect(function()
		Inventory.Open()
	end)

	Remotes.Event("ShopOpen").OnClientEvent:Connect(function(shop: Shop?)
		if not shop then
			hide()
			return
		end
		title.Text = shop.Title
		upgrade.Visible = shop.Shop == "Brakka"
		list.Size = if upgrade.Visible then UDim2.new(1, -24, 1, -184) else UDim2.new(1, -24, 1, -140)
		line.Text = `"{shop.Line}"`
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, offer in shop.Offers do
			local def = Items.Defs[offer.Item]
			local info = Rarity.Info[offer.Rarity] or Rarity.Info.Common
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -8, 0, 60)
			row.BackgroundColor3 = ROW
			row.Parent = list
			corner(row, 8)
			local gear = def and (def.Slot == "Weapon" or def.Set ~= nil)
			stroke(row, if gear then info.Color else EDGE, 1.2)
			picture(row, offer)
			local name = label(row, Fonts.Title, 17, if gear then info.Color else TEXT)
			name.Position = UDim2.fromOffset(64, 6)
			name.Size = UDim2.new(1, -170, 0, 22)
			name.TextScaled = true
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 17
			limit.Parent = name
			name.Text = Items.NameFor(offer.Item, offer.Rarity)
			local about = label(row, Fonts.Body, 13, Color3.fromRGB(180, 170, 158))
			about.Position = UDim2.fromOffset(64, 30)
			about.Size = UDim2.new(1, -170, 0, 22)
			local piece = Armor.Pieces[offer.Item]
			if piece then
				local set = Armor.SetByName[piece.Set]
				-- two short lines: what it is, then its numbers
				about.Position = UDim2.fromOffset(64, 27)
				about.Size = UDim2.new(1, -170, 0, 30)
				about.TextScaled = true
				local fitText = Instance.new("UITextSizeConstraint")
				fitText.MaxTextSize = 12
				fitText.Parent = about
				about.Text = `{offer.Rarity} {if set then set.Kind else "Ring"}` .. "
" .. Armor.Describe(Armor.StatsOf(offer.Item, offer.Rarity, 0))
			elseif def and def.WeaponType then
				about.Text = `{offer.Rarity} {def.WeaponType}  ·  Damage {math.floor(Items.WeaponDamage(offer.Item, offer.Rarity, 0) + 0.5)}`
			else
				about.Text = def and def.Description or ""
			end
			local buy = button(row, `{offer.Price} Gold`, Color3.fromRGB(40, 70, 45))
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -8, 0.5, 0)
			buy.Size = UDim2.fromOffset(96, 36)
			buy.Activated:Connect(function()
				buyRemote:FireServer(i)
			end)
		end
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1, (screen.Y - 100) / panel.Size.Y.Offset, (screen.X * 0.45) / panel.Size.X.Offset)
		gui.Enabled = true
	end)
end

return Shop
