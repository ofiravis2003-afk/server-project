--!strict
-- The Robux store (MonetizationService on the server): a Store button by the Party button opens the passes
-- (owned ones marked) and the gold, each bought through Roblox's own purchase window. In the Depths, falling
-- shows a card offering a Revive where you fell, for a little while.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(ReplicatedStorage.Shared.Device)
local Fonts = require(ReplicatedStorage.Shared.Fonts)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local ROW = Color3.fromRGB(34, 28, 30)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local GREEN = Color3.fromRGB(40, 90, 50)
local REVIVE_SECONDS = 25

local Store = {}

-- What each pass and product is, on screen (prices come from Roblox).
local PASSES = {
	{ Key = "BiggerBag", Name = "Bigger Bag", About = "Your bag holds twice as much.", Owned = "BagSize" },
	{ Key = "VIP", Name = "VIP", About = "+20% gold and XP from every kill, and a VIP tag.", Owned = "VIP" },
	{ Key = "PotionBelt", Name = "Potion Belt", About = "Carry 5 of each potion instead of 3.", Owned = "PotionBonus" },
}
local GOLD_PACKS = {
	{ Key = "GoldSmall", Name = "Small Gold Pouch" },
	{ Key = "GoldMedium", Name = "Gold Sack" },
	{ Key = "GoldLarge", Name = "Gold Chest" },
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance)
	local s = Instance.new("UIStroke")
	s.Color = EDGE
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

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.FontFace = Fonts.Title
	b.TextSize = 18
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	stroke(b)
	return b
end

local prices: { [number]: number } = {}
local function priceOf(id: number, kind: Enum.InfoType): string
	if not prices[id] then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, kind)
		if ok and info and info.PriceInRobux then
			prices[id] = info.PriceInRobux
		end
	end
	return if prices[id] then `R$ {prices[id]}` else "Buy"
end

function Store.Start(inDepths: boolean)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Store"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = button(gui, "Store", Color3.fromRGB(150, 100, 30))
	open.AnchorPoint = Vector2.new(1, 1)
	open.Position = UDim2.new(1, if inDepths then -106 else -198, 1, -14) -- (left of the bag, and the Party button in town)
	open.Size = UDim2.fromOffset(84, 40)
	if Device.Touch() then
		open.AnchorPoint = Vector2.new(1, 0)
		open.Position = UDim2.new(1, if inDepths then -116 else -220, 0, -28)
		open.Size = UDim2.fromOffset(96, 48)
		open.TextSize = 22
	end

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 500)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel)
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local title = label(panel, Fonts.Title, 28, GOLD)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -60, 0, 32)
	title.Text = "Emberwell Store"
	local close = button(panel, "X", Color3.fromRGB(70, 40, 40))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(32, 32)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)
	local rows = Instance.new("ScrollingFrame")
	rows.Position = UDim2.fromOffset(12, 52)
	rows.Size = UDim2.new(1, -24, 1, -64)
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = 6
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.CanvasSize = UDim2.new()
	rows.Parent = panel
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 6)
	stack.Parent = rows

	local function heading(text: string, order: number)
		local h = label(rows, Fonts.Title, 20, GOLD)
		h.Size = UDim2.new(1, -8, 0, 28)
		h.LayoutOrder = order
		h.Text = text
	end
	local function row(order: number, name: string, about: string, price: string, owned: boolean, buy: () -> ())
		local r = Instance.new("Frame")
		r.Size = UDim2.new(1, -8, 0, 62)
		r.BackgroundColor3 = ROW
		r.LayoutOrder = order
		r.Parent = rows
		corner(r, 8)
		local n = label(r, Fonts.Title, 19, TEXT)
		n.Position = UDim2.fromOffset(12, 6)
		n.Size = UDim2.new(1, -140, 0, 24)
		n.Text = name
		local a = label(r, Fonts.Body, 14, Color3.fromRGB(190, 180, 165))
		a.Position = UDim2.fromOffset(12, 32)
		a.Size = UDim2.new(1, -140, 0, 22)
		a.TextWrapped = true
		a.Text = about
		local b = button(r, if owned then "Owned" else price, if owned then Color3.fromRGB(50, 50, 55) else GREEN)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -10, 0.5, 0)
		b.Size = UDim2.fromOffset(112, 38)
		b.Active = not owned
		b.AutoButtonColor = not owned
		if not owned then
			b.MouseButton1Click:Connect(buy)
		end
	end

	local function redraw()
		for _, child in rows:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		heading("Passes", 0)
		for i, pass in PASSES do
			local id = (Config.Passes :: any)[pass.Key] :: number
			row(i, pass.Name, pass.About, priceOf(id, Enum.InfoType.GamePass), player:GetAttribute(pass.Owned) ~= nil, function()
				MarketplaceService:PromptGamePassPurchase(player, id)
			end)
		end
		heading("Gold", 10)
		for i, pack in GOLD_PACKS do
			local product = (Config.Products :: any)[pack.Key]
			row(10 + i, pack.Name, `{product.Gold} gold for the shops of Emberhold.`, priceOf(product.Id, Enum.InfoType.Product), false, function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
		end
	end

	open.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			local screen = workspace.CurrentCamera.ViewportSize
			fit.Scale = math.min(1.3, (screen.Y - 90) / panel.Size.Y.Offset, (screen.X - 24) / panel.Size.X.Offset)
			task.spawn(redraw) -- (prices are asked of Roblox once)
		end
	end)
	for _, pass in PASSES do
		player:GetAttributeChangedSignal(pass.Owned):Connect(function()
			if panel.Visible then
				redraw()
			end
		end)
	end

	-- The Depths: falling offers a Revive where you fell
	if not inDepths then
		return
	end
	local reviveId = (Config.Products :: any).Revive.Id :: number
	local function offerRevive()
		local old = gui:FindFirstChild("Revive")
		if old then
			old:Destroy()
		end
		local card = Instance.new("Frame")
		card.Name = "Revive"
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, 140)
		card.Size = UDim2.fromOffset(360, 116)
		card.BackgroundColor3 = PANEL
		card.BackgroundTransparency = 0.05
		card.Parent = gui
		corner(card, 10)
		stroke(card)
		local text = label(card, Fonts.Title, 22, GOLD)
		text.Position = UDim2.fromOffset(0, 10)
		text.Size = UDim2.new(1, 0, 0, 28)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.Text = "You have fallen..."
		local yes = button(card, "Revive here  " .. priceOf(reviveId, Enum.InfoType.Product), GREEN)
		yes.Position = UDim2.new(0.5, -168, 1, -56)
		yes.Size = UDim2.fromOffset(200, 42)
		yes.MouseButton1Click:Connect(function()
			MarketplaceService:PromptProductPurchase(player, reviveId)
		end)
		local no = button(card, "No thanks", Color3.fromRGB(70, 40, 40))
		no.Position = UDim2.new(0.5, 40, 1, -56)
		no.Size = UDim2.fromOffset(128, 42)
		local function hide()
			if card.Parent then
				TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 1, 140) }):Play()
				task.delay(0.35, function()
					card:Destroy()
				end)
			end
		end
		no.MouseButton1Click:Connect(hide)
		MarketplaceService.PromptProductPurchaseFinished:Once(function(_userId, productId, bought)
			if productId == reviveId and bought then
				hide()
			end
		end)
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -24) }):Play()
		task.delay(REVIVE_SECONDS, hide)
	end
	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(offerRevive)
		end
	end
	if player.Character then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return Store
