--!strict
-- "My Dragons": the 🐉 button on the left opens the player's whole collection.
--   Dragons tab: pick a dragon to see it in 3D, make it active (earning + following you),
--                lock it, sell it, or breed it with another dragon.
--   Index tab:   the Dragon Index, every gene in the game and which ones you've discovered,
--                plus your 🏆 World Firsts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DragonAnimator = require(ReplicatedStorage.Shared.DragonAnimator)
local DragonBuilder = require(ReplicatedStorage.Shared.DragonBuilder)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Genes = require(ReplicatedStorage.Shared.Genes)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DARK = Color3.fromRGB(25, 20, 30)
local CARD = Color3.fromRGB(45, 38, 55)
local GREEN = Color3.fromRGB(80, 200, 110)
local RED = Color3.fromRGB(215, 75, 70)
local GREY = Color3.fromRGB(110, 105, 120)
local PINK = Color3.fromRGB(235, 110, 170)
local ORANGE = Color3.fromRGB(255, 160, 60)
local SELL_CONFIRM_SECONDS = 3

type Dragon = {
	Genes: Genes.DragonGenes,
	Born: number,
	Source: string,
	Generation: number?,
	Locked: boolean?,
	RestUntil: number?,
	WorldFirst: boolean?,
}
type State = {
	Dragons: { [string]: Dragon },
	Active: { string },
	Slots: number,
	Max: number,
	Index: { [string]: boolean },
	WorldFirsts: { string },
}
type Tab = "Dragons" | "Index"

local DragonsPanel = {}

local state: State = {
	Dragons = {},
	Active = {},
	Slots = Config.Dragons.ActiveSlots,
	Max = Config.Dragons.MaxOwned,
	Index = {},
	WorldFirsts = {},
}
local tab: Tab = "Dragons"
local selectedId: string?
local breedFrom: string? -- set while the player is picking a partner for this dragon
local breedWith: string? -- the partner they picked, waiting for "Confirm"
local sellArmedUntil = 0
local showMessage: (string) -> () = function() end

local screenGui: ScreenGui
local window: Frame
local header: TextLabel
local dragonsTabButton: TextButton
local indexTabButton: TextButton
local grid: ScrollingFrame
local indexList: ScrollingFrame
local detail: Frame
local viewport: ViewportFrame
local viewportCamera: Camera
local previewModel: Model?
local previewRig: DragonAnimator.Rig?
local detailName: TextLabel
local detailRarity: TextLabel
local detailStats: TextLabel
local mainButton: TextButton
local lockButton: TextButton
local sellButton: TextButton
local breedButton: TextButton
local actionRemote = Remotes.Function("DragonAction")
local breedRemote = Remotes.Function("BreedDragons")

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

local function restLeft(dragon: Dragon): number
	return math.max(0, math.ceil((dragon.RestUntil or 0) - workspace:GetServerTimeNow()))
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
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
	local distance = reach / math.tan(math.rad(camera.FieldOfView / 2)) * 1.2
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

local function showPreview(genes: Genes.DragonGenes?)
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
		previewRig = nil
	end
	if genes then
		local model = DragonBuilder.Build(genes)
		model:PivotTo(CFrame.new())
		model.Parent = viewport
		frameModel(viewportCamera, model)
		previewModel = model
		previewRig = DragonAnimator.Rig(model)
	end
end

local function cancelBreeding()
	breedFrom = nil
	breedWith = nil
end

local function renderDetail()
	sellButton.Visible = false
	breedButton.Visible = false
	lockButton.Visible = false
	mainButton.Visible = false

	-- Step 2 of breeding: confirm the pair.
	local parentA = breedFrom and state.Dragons[breedFrom]
	local parentB = breedWith and state.Dragons[breedWith]
	if parentA and parentB then
		showPreview(parentB.Genes)
		detailName.Text = `{Genes.GetName(parentA.Genes)} + {Genes.GetName(parentB.Genes)}`
		detailRarity.Text = `💞 Breed for {Config.Currency.Icon} {NumberFormat.Abbreviate(
			DragonStats.BreedFee(parentA.Genes, parentB.Genes)
		)}`
		detailRarity.TextColor3 = PINK
		detailStats.Text = `The egg hatches in {formatTime(DragonStats.BreedTime(parentA.Genes, parentB.Genes))}`
		mainButton.Visible = true
		mainButton.Text = "Confirm 💞"
		mainButton.BackgroundColor3 = PINK
		lockButton.Visible = true
		lockButton.Text = "Cancel"
		lockButton.BackgroundColor3 = GREY
		return
	end

	-- Step 1 of breeding: pick a partner.
	if parentA then
		showPreview(parentA.Genes)
		detailName.Text = Genes.GetName(parentA.Genes)
		detailRarity.Text = "💞 Now tap a partner on the left"
		detailRarity.TextColor3 = PINK
		detailStats.Text = "Babies get each trait from one parent, and sometimes a mutation!"
		lockButton.Visible = true
		lockButton.Text = "Cancel"
		lockButton.BackgroundColor3 = GREY
		return
	end

	local dragon = selectedId and state.Dragons[selectedId]
	if not dragon or not selectedId then
		showPreview(nil)
		detailName.Text = if next(state.Dragons) then "Pick a dragon" else "No dragons yet!"
		detailRarity.Text = if next(state.Dragons) then "" else "Hatch an egg at the shop"
		detailRarity.TextColor3 = Color3.fromRGB(190, 180, 200)
		detailStats.Text = ""
		return
	end

	local genes = dragon.Genes
	local rarity = Genes.GetRarity(genes)
	showPreview(genes)
	detailName.Text = Genes.GetName(genes)
	detailRarity.Text = rarity.Name .. (if dragon.WorldFirst then "  •  🏆 World First" else "")
	detailRarity.TextColor3 = rarity.Color
	detailStats.Text = `{Config.Currency.Icon} {DragonStats.Income(genes)}/s  •  Sells {NumberFormat.Abbreviate(
		DragonStats.SellPrice(genes)
	)}  •  Gen {dragon.Generation or 1}`

	local active = isActive(selectedId)
	mainButton.Visible = true
	mainButton.Text = if active then "Put away" else "Make active"
	mainButton.BackgroundColor3 = if active then GREY else GREEN
	lockButton.Visible = true
	lockButton.Text = if dragon.Locked then "🔓 Unlock" else "🔒 Lock"
	lockButton.BackgroundColor3 = GREY
	sellButton.Visible = true
	sellButton.Text = if os.clock() < sellArmedUntil then "Sure? Sell!" else "Sell"
	sellButton.BackgroundColor3 = if dragon.Locked then GREY else RED
	breedButton.Visible = true
	local resting = restLeft(dragon)
	breedButton.Text = if resting > 0 then `💤 Resting {formatTime(resting)}` else "💞 Breed"
	breedButton.BackgroundColor3 = if resting > 0 then GREY else PINK
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
		local highlighted = id == selectedId or id == breedFrom or id == breedWith
		-- While picking a partner, dragons that can't breed right now are dimmed.
		local unavailable = breedFrom ~= nil and (id == breedFrom or restLeft(dragon) > 0)

		local card = Instance.new("TextButton")
		card.Name = id
		card.LayoutOrder = order
		card.Text = ""
		card.BackgroundColor3 = if highlighted then Color3.fromRGB(75, 65, 90) else CARD
		card.BackgroundTransparency = if unavailable and id ~= breedFrom then 0.6 else 0
		card.AutoButtonColor = true
		card.Parent = grid
		corner(card, 10)

		local stroke = Instance.new("UIStroke")
		stroke.Color = if id == breedFrom or id == breedWith then PINK else rarity.Color
		stroke.Thickness = if highlighted then 3 else 1.5
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

		local badges = (if dragon.WorldFirst then "🏆" else "")
			.. (if isActive(id) then "⭐" else "")
			.. (if dragon.Locked then "🔒" else "")
			.. (if restLeft(dragon) > 0 then "💤" else "")
		label(card, badges, UDim2.new(1, -78, 0, 4), UDim2.fromOffset(74, 20))
		label(card, Genes.GetName(genes), UDim2.fromOffset(6, 26), UDim2.new(1, -12, 0, 22))
		label(card, rarity.Name, UDim2.fromOffset(6, 48), UDim2.new(0.55, -6, 0, 16), rarity.Color)
		label(card, `{DragonStats.Income(genes)}/s`, UDim2.new(0.55, 0, 0, 48), UDim2.new(0.45, -6, 0, 16), ORANGE)

		card.Activated:Connect(function()
			if breedFrom then
				if id == breedFrom then
					return
				end
				if restLeft(dragon) > 0 then
					showMessage(`{Genes.GetName(genes)} is resting. Try again in {formatTime(restLeft(dragon))}.`)
					return
				end
				breedWith = id
			else
				selectedId = id
				sellArmedUntil = 0
			end
			renderGrid()
			renderDetail()
		end)
	end

	if breedFrom then
		header.Text = "💞 Pick a partner"
	else
		header.Text =
			`Dragons {count}/{state.Max}  •  Active {#state.Active}/{state.Slots}  •  {Config.Currency.Icon} {totalIncome()}/s`
	end
end

local function renderIndex()
	for _, child in indexList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local found, total = 0, 0
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, trait in Genes.Traits do
		local options = Genes.Options[trait]
		local traitFound = 0
		for _, option in options do
			if state.Index[trait .. "." .. option.Id] then
				traitFound += 1
			end
		end
		found += traitFound
		total += #options

		local title = label(indexList, `{trait}  {traitFound}/{#options}`, UDim2.new(), UDim2.new(1, -12, 0, 26))
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.LayoutOrder = nextOrder()

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, -12, 0, 0)
		row.LayoutOrder = nextOrder()
		row.Parent = indexList
		local rowLayout = Instance.new("UIGridLayout")
		rowLayout.CellSize = UDim2.fromOffset(112, 40)
		rowLayout.CellPadding = UDim2.fromOffset(6, 6)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row

		for i, option in options do
			local known = state.Index[trait .. "." .. option.Id] == true
			local rarity: Rarity.Tier = Rarity.Get(option.Rarity)
			local cell = Instance.new("Frame")
			cell.LayoutOrder = i
			cell.BackgroundColor3 = if known then CARD else Color3.fromRGB(35, 30, 40)
			cell.Parent = row
			corner(cell, 8)
			local stroke = Instance.new("UIStroke")
			stroke.Color = if known then rarity.Color else Color3.fromRGB(70, 65, 75)
			stroke.Thickness = 1.5
			stroke.Parent = cell
			if known and option.Color then
				local swatch = Instance.new("Frame")
				swatch.Position = UDim2.fromOffset(6, 13)
				swatch.Size = UDim2.fromOffset(14, 14)
				swatch.BackgroundColor3 = option.Color
				swatch.Parent = cell
				corner(swatch, 7)
			end
			local name = label(
				cell,
				if known then option.Id else "???",
				UDim2.fromOffset(if known and option.Color then 24 else 6, 4),
				UDim2.new(1, if known and option.Color then -30 else -12, 0, 18),
				if known then Color3.new(1, 1, 1) else Color3.fromRGB(120, 115, 125)
			)
			name.TextXAlignment = Enum.TextXAlignment.Left
			label(
				cell,
				rarity.Name,
				UDim2.fromOffset(if known and option.Color then 24 else 6, 22),
				UDim2.new(1, -30, 0, 14),
				if known then rarity.Color else Color3.fromRGB(90, 85, 95)
			).TextXAlignment =
				Enum.TextXAlignment.Left
		end
	end

	local firsts = label(
		indexList,
		if #state.WorldFirsts > 0
			then `🏆 Your World Firsts: {table.concat(state.WorldFirsts, ", ")}`
			else "🏆 No World Firsts yet. Hatch an Epic or rarer dragon nobody has found before!",
		UDim2.new(),
		UDim2.new(1, -12, 0, 44),
		Color3.fromRGB(255, 210, 100)
	)
	firsts.TextWrapped = true
	firsts.LayoutOrder = nextOrder()

	header.Text = `Dragon Index  {found}/{total} genes discovered`
end

local function render()
	local onIndex = tab == "Index"
	grid.Visible = not onIndex
	detail.Visible = not onIndex
	indexList.Visible = onIndex
	dragonsTabButton.BackgroundColor3 = if onIndex then CARD else ORANGE
	indexTabButton.BackgroundColor3 = if onIndex then ORANGE else CARD
	if onIndex then
		renderIndex()
	else
		renderGrid()
		renderDetail()
	end
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

local function confirmBreeding()
	local a, b = breedFrom, breedWith
	if not a or not b then
		return
	end
	local ok, result = pcall(breedRemote.InvokeServer, breedRemote, a, b)
	if ok and type(result) == "table" then
		if result.Message then
			showMessage(result.Message)
		end
		if result.Ok then
			cancelBreeding()
		end
	end
	render()
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
	limit.MaxSize = Vector2.new(780, 480)
	limit.Parent = window

	dragonsTabButton = button(window, "🐉 Dragons", UDim2.fromOffset(12, 8), UDim2.fromOffset(120, 34), ORANGE)
	indexTabButton = button(window, "📖 Index", UDim2.fromOffset(138, 8), UDim2.fromOffset(110, 34), CARD)
	header = label(window, "", UDim2.fromOffset(258, 12), UDim2.new(1, -318, 0, 28))
	header.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(window, "X", UDim2.new(1, -50, 0, 8), UDim2.fromOffset(40, 34), RED)
	close.Activated:Connect(function()
		window.Visible = false
		cancelBreeding()
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

	indexList = Instance.new("ScrollingFrame")
	indexList.Position = UDim2.fromOffset(12, 50)
	indexList.Size = UDim2.new(1, -24, 1, -62)
	indexList.BackgroundTransparency = 1
	indexList.ScrollBarThickness = 6
	indexList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	indexList.CanvasSize = UDim2.new()
	indexList.Visible = false
	indexList.Parent = window
	local indexLayout = Instance.new("UIListLayout")
	indexLayout.Padding = UDim.new(0, 6)
	indexLayout.SortOrder = Enum.SortOrder.LayoutOrder
	indexLayout.Parent = indexList

	detail = Instance.new("Frame")
	detail.Position = UDim2.new(0.6, 0, 0, 50)
	detail.Size = UDim2.new(0.4, -12, 1, -62)
	detail.BackgroundColor3 = CARD
	detail.Parent = window
	corner(detail, 12)

	viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 0.42, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(160, 160, 170)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	viewport.Parent = detail
	viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 40
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera

	detailName = label(detail, "", UDim2.new(0, 8, 0.43, 0), UDim2.new(1, -16, 0.08, 0))
	detailRarity = label(detail, "", UDim2.new(0, 8, 0.51, 0), UDim2.new(1, -16, 0.06, 0))
	detailStats = label(detail, "", UDim2.new(0, 8, 0.58, 0), UDim2.new(1, -16, 0.05, 0), ORANGE)

	mainButton = button(detail, "Make active", UDim2.new(0, 10, 0.65, 0), UDim2.new(1, -20, 0.09, 0), GREEN)
	lockButton = button(detail, "🔒 Lock", UDim2.new(0, 10, 0.76, 0), UDim2.new(0.5, -15, 0.09, 0), GREY)
	sellButton = button(detail, "Sell", UDim2.new(0.5, 5, 0.76, 0), UDim2.new(0.5, -15, 0.09, 0), RED)
	breedButton = button(detail, "💞 Breed", UDim2.new(0, 10, 0.87, 0), UDim2.new(1, -20, 0.09, 0), PINK)

	toggle.Activated:Connect(function()
		window.Visible = not window.Visible
		cancelBreeding()
		if window.Visible then
			render()
		end
	end)
	dragonsTabButton.Activated:Connect(function()
		tab = "Dragons"
		render()
	end)
	indexTabButton.Activated:Connect(function()
		tab = "Index"
		cancelBreeding()
		render()
	end)

	mainButton.Activated:Connect(function()
		if breedFrom and breedWith then
			confirmBreeding()
		elseif selectedId then
			act(if isActive(selectedId) then "Deactivate" else "Activate")
		end
	end)
	lockButton.Activated:Connect(function()
		if breedFrom then
			cancelBreeding()
			render()
			return
		end
		local dragon = selectedId and state.Dragons[selectedId]
		if dragon then
			act(if dragon.Locked then "Unlock" else "Lock")
		end
	end)
	breedButton.Activated:Connect(function()
		local dragon = selectedId and state.Dragons[selectedId]
		if not dragon or not selectedId then
			return
		end
		if restLeft(dragon) > 0 then
			showMessage(`This dragon is resting. Try again in {formatTime(restLeft(dragon))}.`)
			return
		end
		breedFrom = selectedId
		breedWith = nil
		render()
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
				if window.Visible and tab == "Dragons" then
					renderDetail()
				end
			end)
		end
	end)

	-- Animate the preview dragon, and keep "resting" countdowns fresh.
	local lastRefresh = 0
	RunService.RenderStepped:Connect(function()
		if not window.Visible then
			return
		end
		local t = os.clock()
		if previewRig then
			DragonAnimator.Apply(previewRig, CFrame.Angles(0, t * 0.6, 0), t * DragonAnimator.FlapSpeed(0.2), 0.2)
		end
		if tab == "Dragons" and not breedFrom and t - lastRefresh > 1 then
			lastRefresh = t
			local dragon = selectedId and state.Dragons[selectedId]
			if dragon and (dragon.RestUntil or 0) > workspace:GetServerTimeNow() - 2 then
				local resting = restLeft(dragon)
				breedButton.Text = if resting > 0 then `💤 Resting {formatTime(resting)}` else "💞 Breed"
				breedButton.BackgroundColor3 = if resting > 0 then GREY else PINK
			end
		end
	end)
end

function DragonsPanel.Start(onMessage: (string) -> ())
	showMessage = onMessage
	build()

	Remotes.Event("DragonsUpdated").OnClientEvent:Connect(function(newState: State)
		state = newState
		state.Index = state.Index or {}
		state.WorldFirsts = state.WorldFirsts or {}
		if selectedId and not state.Dragons[selectedId] then
			selectedId = nil
		end
		if (breedFrom and not state.Dragons[breedFrom]) or (breedWith and not state.Dragons[breedWith]) then
			cancelBreeding()
		end
		if window.Visible then
			render()
		end
	end)
end

return DragonsPanel
