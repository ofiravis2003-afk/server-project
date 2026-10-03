--!strict
-- "My Dragons": the 🐉 button on the left opens the player's whole collection.
-- Pick a dragon to see it in 3D, make it active (earning + following you), lock it, or sell it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Genes = require(ReplicatedStorage.Shared.Genes)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DARK = Color3.fromRGB(25, 20, 30)
local CARD = Color3.fromRGB(45, 38, 55)
local GREEN = Color3.fromRGB(80, 200, 110)
local RED = Color3.fromRGB(215, 75, 70)
local GREY = Color3.fromRGB(110, 105, 120)
local ORANGE = Color3.fromRGB(255, 160, 60)
local SELL_CONFIRM_SECONDS = 3

type Dragon = { Genes: Genes.DragonGenes, Born: number, Source: string, Locked: boolean? }
type State = { Dragons: { [string]: Dragon }, Active: { string }, Slots: number, Max: number }

local DragonsPanel = {}

local state: State = { Dragons = {}, Active = {}, Slots = Config.Dragons.ActiveSlots, Max = Config.Dragons.MaxOwned }
local selectedId: string?
local sellArmedUntil = 0
local showMessage: (string) -> () = function() end

local screenGui: ScreenGui
local window: Frame
local header: TextLabel
local grid: ScrollingFrame
local viewport: ViewportFrame
local viewportCamera: Camera
local previewModel: Model?
local detailName: TextLabel
local detailRarity: TextLabel
local detailStats: TextLabel
local activateButton: TextButton
local lockButton: TextButton
local sellButton: TextButton
local actionRemote = Remotes.Function("DragonAction")

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Position = position
	b.Size = size
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = b
	return b
end

local function isActive(id: string): boolean
	return table.find(state.Active, id) ~= nil
end

-- Active first, then rarest, then best earners.
local function sortedIds(): { string }
	local ids = {}
	for id in state.Dragons do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local activeA, activeB = isActive(a), isActive(b)
		if activeA ~= activeB then
			return activeA
		end
		local genesA, genesB = state.Dragons[a].Genes, state.Dragons[b].Genes
		local rarityA, rarityB = Genes.GetRarity(genesA).Order, Genes.GetRarity(genesB).Order
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		local incomeA, incomeB = DragonStats.Income(genesA), DragonStats.Income(genesB)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return a < b
	end)
	return ids
end

local function frameModel(camera: Camera, model: Model)
	local box, size = model:GetBoundingBox()
	local reach = math.sqrt(math.max(size.X, size.Z) ^ 2 + size.Y ^ 2) / 2
	local distance = reach / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(-0.55, 0.35, -1).Unit * distance, box.Position)
end

local function totalIncome(): number
	local total = 0
	for _, id in state.Active do
		local dragon = state.Dragons[id]
		if dragon then
			total += DragonStats.Income(dragon.Genes)
		end
	end
	return total
end

local function renderDetail()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	local dragon = selectedId and state.Dragons[selectedId]
	local hasDragon = dragon ~= nil
	activateButton.Visible = hasDragon
	lockButton.Visible = hasDragon
	sellButton.Visible = hasDragon
	if not dragon or not selectedId then
		detailName.Text = if next(state.Dragons) then "Pick a dragon" else "No dragons yet!"
		detailRarity.Text = if next(state.Dragons) then "" else "Hatch an egg at the shop"
		detailRarity.TextColor3 = Color3.fromRGB(190, 180, 200)
		detailStats.Text = ""
		return
	end

	local genes = dragon.Genes
	local rarity = Genes.GetRarity(genes)
	detailName.Text = Genes.GetName(genes)
	detailRarity.Text = rarity.Name
	detailRarity.TextColor3 = rarity.Color
	detailStats.Text = `{Config.Currency.Icon} {DragonStats.Income(genes)}/s   •   Sells for {NumberFormat.Abbreviate(
		DragonStats.SellPrice(genes)
	)}`

	local active = isActive(selectedId)
	activateButton.Text = if active then "Put away" else "Make active"
	activateButton.BackgroundColor3 = if active then GREY else GREEN
	lockButton.Text = if dragon.Locked then "🔓 Unlock" else "🔒 Lock"
	sellButton.Text = if os.clock() < sellArmedUntil then "Sure? Sell!" else "Sell"
	sellButton.BackgroundColor3 = if dragon.Locked then GREY else RED

	local model = DragonBuilder.Build(genes)
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	frameModel(viewportCamera, model)
	previewModel = model
end

local function renderGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local count = 0
	for order, id in sortedIds() do
		count += 1
		local dragon = state.Dragons[id]
		local genes = dragon.Genes
		local rarity = Genes.GetRarity(genes)

		local card = Instance.new("TextButton")
		card.Name = id
		card.LayoutOrder = order
		card.Text = ""
		card.BackgroundColor3 = if id == selectedId then Color3.fromRGB(75, 65, 90) else CARD
		card.AutoButtonColor = true
		card.Parent = grid
		corner(card, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = rarity.Color
		stroke.Thickness = if id == selectedId then 3 else 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = card

		-- Body and accent colour dots, so dragons are easy to tell apart.
		for i, trait in { "Body", "Accent" } do
			local dot = Instance.new("Frame")
			dot.Position = UDim2.fromOffset(8 + (i - 1) * 18, 8)
			dot.Size = UDim2.fromOffset(14, 14)
			dot.BackgroundColor3 = Genes.Get(trait, (genes :: any)[trait]).Color or Color3.new(1, 1, 1)
			dot.Parent = card
			corner(dot, 7)
		end

		local badges = (if isActive(id) then "⭐" else "") .. (if dragon.Locked then "🔒" else "")
		label(card, badges, UDim2.new(1, -46, 0, 4), UDim2.fromOffset(42, 20))
		label(card, Genes.GetName(genes), UDim2.fromOffset(6, 26), UDim2.new(1, -12, 0, 22))
		label(card, rarity.Name, UDim2.fromOffset(6, 48), UDim2.new(0.55, -6, 0, 16), rarity.Color)
		label(card, `{DragonStats.Income(genes)}/s`, UDim2.new(0.55, 0, 0, 48), UDim2.new(0.45, -6, 0, 16), ORANGE)

		card.Activated:Connect(function()
			selectedId = id
			sellArmedUntil = 0
			renderGrid()
			renderDetail()
		end)
	end

	header.Text =
		`My Dragons {count}/{state.Max}   •   Active {#state.Active}/{state.Slots}   •   {Config.Currency.Icon} {totalIncome()}/s`
end

local function act(action: string)
	local id = selectedId
	if not id then
		return
	end
	local ok, result = pcall(actionRemote.InvokeServer, actionRemote, action, id)
	if ok and type(result) == "table" and result.Message then
		showMessage(result.Message)
	end
end

local function build()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Dragons"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local toggle = button(screenGui, "🐉", UDim2.new(0, 12, 0.5, -36), UDim2.fromOffset(64, 64), CARD)
	toggle.Name = "DragonsButton"
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = ORANGE
	toggleStroke.Thickness = 2
	toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toggleStroke.Parent = toggle

	window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.85, 0.75)
	window.BackgroundColor3 = DARK
	window.BackgroundTransparency = 0.05
	window.Visible = false
	window.Parent = screenGui
	corner(window, 16)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 470)
	limit.Parent = window

	header = label(window, "My Dragons", UDim2.fromOffset(16, 10), UDim2.new(1, -80, 0, 30))
	header.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(window, "X", UDim2.new(1, -50, 0, 8), UDim2.fromOffset(40, 36), RED)
	close.Activated:Connect(function()
		window.Visible = false
	end)

	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(12, 50)
	grid.Size = UDim2.new(0.6, -18, 1, -62)
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(138, 70)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingLeft = UDim.new(0, 4)
	gridPadding.Parent = grid

	local detail = Instance.new("Frame")
	detail.Position = UDim2.new(0.6, 0, 0, 50)
	detail.Size = UDim2.new(0.4, -12, 1, -62)
	detail.BackgroundColor3 = CARD
	detail.Parent = window
	corner(detail, 12)

	viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 0.45, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(160, 160, 170)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	viewport.Parent = detail
	viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 40
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera

	detailName = label(detail, "", UDim2.new(0, 8, 0.46, 0), UDim2.new(1, -16, 0.08, 0))
	detailRarity = label(detail, "", UDim2.new(0, 8, 0.54, 0), UDim2.new(1, -16, 0.06, 0))
	detailStats = label(detail, "", UDim2.new(0, 8, 0.61, 0), UDim2.new(1, -16, 0.05, 0), ORANGE)

	activateButton = button(detail, "Make active", UDim2.new(0, 10, 0.69, 0), UDim2.new(1, -20, 0.09, 0), GREEN)
	lockButton = button(detail, "🔒 Lock", UDim2.new(0, 10, 0.8, 0), UDim2.new(0.5, -15, 0.09, 0), GREY)
	sellButton = button(detail, "Sell", UDim2.new(0.5, 5, 0.8, 0), UDim2.new(0.5, -15, 0.09, 0), RED)

	toggle.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			renderGrid()
			renderDetail()
		end
	end)

	activateButton.Activated:Connect(function()
		if selectedId then
			act(if isActive(selectedId) then "Deactivate" else "Activate")
		end
	end)
	lockButton.Activated:Connect(function()
		local dragon = selectedId and state.Dragons[selectedId]
		if dragon then
			act(if dragon.Locked then "Unlock" else "Lock")
		end
	end)
	-- Selling takes two presses, so nobody loses a dragon by accident.
	sellButton.Activated:Connect(function()
		local dragon = selectedId and state.Dragons[selectedId]
		if not dragon then
			return
		end
		if dragon.Locked then
			showMessage("This dragon is locked. Unlock it first to sell it.")
		elseif os.clock() < sellArmedUntil then
			sellArmedUntil = 0
			act("Sell")
		else
			sellArmedUntil = os.clock() + SELL_CONFIRM_SECONDS
			renderDetail()
			task.delay(SELL_CONFIRM_SECONDS, function()
				if window.Visible then
					renderDetail()
				end
			end)
		end
	end)

	-- Slowly turn the preview dragon.
	RunService.RenderStepped:Connect(function()
		if previewModel and window.Visible then
			previewModel:PivotTo(CFrame.Angles(0, os.clock() * 0.6, 0))
		end
	end)
end

function DragonsPanel.Start(onMessage: (string) -> ())
	showMessage = onMessage
	build()

	Remotes.Event("DragonsUpdated").OnClientEvent:Connect(function(newState: State)
		state = newState
		if selectedId and not state.Dragons[selectedId] then
			selectedId = nil
		end
		if window.Visible then
			renderGrid()
			renderDetail()
		end
	end)
end

return DragonsPanel
