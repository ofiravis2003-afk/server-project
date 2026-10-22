--!strict
-- The bag: a button (or the B key) opens a grid of everything the player owns, each in its rarity's color
-- with a small 3D view. Clicking an item shows its name, stats and how it compares with the equipped weapon
-- (green up / red down), with Equip, and Sell when standing at a merchant in Emberhold (the server marks
-- the player "AtShop"); anywhere else the button drops the item instead. Epic or better asks once more.
-- A red dot on the button means something new came in since the bag was last opened.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.Shared.Armor)
local Device = require(ReplicatedStorage.Shared.Device)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local SLOT = Color3.fromRGB(34, 28, 30)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local UP = Color3.fromRGB(110, 220, 120)
local DOWN = Color3.fromRGB(235, 90, 80)
local COLUMNS = 6
local CELL = 64
local GAP = 6

type SavedItem = { Item: string, Rarity: string, Upgrade: number?, Count: number? }
type Snapshot = { Items: { [string]: SavedItem }, Equipped: { [string]: string }, BagSize: number }

local Inventory = {}

local opener: (() -> ())? = nil

-- Opens the bag (a shop's "Sell from your bag" button).
function Inventory.Open()
	if opener then
		opener()
	end
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
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
	stroke(b, EDGE, 1.5)
	return b
end

-- A still 3D picture of the item, turned a little so its shape reads.
local function preview(parent: Instance, saved: SavedItem, size: UDim2, position: UDim2)
	local view = Instance.new("ViewportFrame")
	view.Size = size
	view.Position = position
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(215, 205, 195)
	view.LightColor = Color3.fromRGB(255, 235, 210)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = parent
	local model = ItemModels.Build(saved.Item, saved.Rarity)
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	local box, extents = model:GetBoundingBox()
	local distance = math.max(extents.X, extents.Y, extents.Z) * 1.45 + 0.5
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(distance * 0.55, distance * 0.3, distance * 0.8), box.Position)
end

local RARITY_RANK: { [string]: number } = {}
for i, name in Rarity.Order do
	RARITY_RANK[name] = i
end

function Inventory.Start()
	local player = Players.LocalPlayer
	local actionRemote = Remotes.Event("InventoryAction")
	local snapshot: Snapshot = { Items = {}, Equipped = {}, BagSize = 30 }
	local selected: string? = nil
	local confirmSell = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "Inventory"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The bag button, bottom-right, with its red "something new" dot.
	local open = button(gui, "Bag", PANEL)
	open.AnchorPoint = Vector2.new(1, 1)
	open.Position = UDim2.new(1, -14, 1, -14)
	open.Size = UDim2.fromOffset(84, 40)
	if Device.Touch() then
		-- (the thumb's corner is the jump button's; the bag goes up top, bigger)
		open.AnchorPoint = Vector2.new(1, 0)
		open.Position = UDim2.new(1, -12, 0, 8)
		open.Size = UDim2.fromOffset(96, 48)
		open.TextSize = 22
	end
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(14, 14)
	dot.Position = UDim2.new(1, -8, 0, -6)
	dot.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
	dot.Visible = false
	dot.Parent = open
	corner(dot, 7)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(COLUMNS * (CELL + GAP) + 24 + 250, 430)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel, EDGE, 2)
	local fit = Instance.new("UIScale")
	fit.Parent = panel

	local title = label(panel, Fonts.Title, 26, GOLD)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.fromOffset(300, 32)

	local close = button(panel, "X", Color3.fromRGB(60, 30, 30))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(32, 32)

	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(12, 48)
	grid.Size = UDim2.new(0, COLUMNS * (CELL + GAP) + 10, 1, -60)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL, CELL)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	-- The details of the chosen item, on the right.
	local details = Instance.new("Frame")
	details.AnchorPoint = Vector2.new(1, 0)
	details.Position = UDim2.new(1, -12, 0, 48)
	details.Size = UDim2.new(0, 236, 1, -60)
	details.BackgroundColor3 = SLOT
	details.Parent = panel
	corner(details, 8)
	local big = Instance.new("Frame")
	big.Size = UDim2.new(1, 0, 0, 120)
	big.BackgroundTransparency = 1
	big.Parent = details
	local name = label(details, Fonts.Title, 22, TEXT)
	name.Position = UDim2.fromOffset(12, 124)
	name.Size = UDim2.new(1, -24, 0, 26)
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 22
	nameLimit.Parent = name
	local kind = label(details, Fonts.Body, 15, TEXT)
	kind.Position = UDim2.fromOffset(12, 152)
	kind.Size = UDim2.new(1, -24, 0, 18)
	local stats = label(details, Fonts.Body, 16, TEXT)
	stats.Position = UDim2.fromOffset(12, 178)
	stats.Size = UDim2.new(1, -24, 0, 60)
	stats.RichText = true
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.TextWrapped = true
	local equip = button(details, "Equip", Color3.fromRGB(40, 70, 45))
	equip.Position = UDim2.new(0, 12, 1, -92)
	equip.Size = UDim2.new(1, -24, 0, 36)
	local sell = button(details, "Sell", Color3.fromRGB(80, 55, 25))
	sell.Position = UDim2.new(0, 12, 1, -48)
	sell.Size = UDim2.new(1, -24, 0, 36)
	local empty = label(details, Fonts.Body, 16, Color3.fromRGB(160, 150, 140))
	empty.Size = UDim2.fromScale(1, 1)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.Text = "Choose an item"

	local function isWorn(id: string?): boolean
		if not id then
			return false
		end
		for _, wornId in snapshot.Equipped do
			if wornId == id then
				return true
			end
		end
		return false
	end

	local function sortedIds(): { string }
		local ids = {}
		for id in snapshot.Items do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local equippedA = isWorn(a)
			local equippedB = isWorn(b)
			if equippedA ~= equippedB then
				return equippedA
			end
			local ia, ib = snapshot.Items[a], snapshot.Items[b]
			local ga, gb = Items.IsGear(ia.Item), Items.IsGear(ib.Item)
			if ga ~= gb then
				return ga
			end
			local ra, rb = RARITY_RANK[ia.Rarity] or 0, RARITY_RANK[ib.Rarity] or 0
			if ra ~= rb then
				return ra > rb
			end
			if ia.Item ~= ib.Item then
				return ia.Item < ib.Item
			end
			return (tonumber(a) or 0) > (tonumber(b) or 0)
		end)
		return ids
	end

	local function compare(value: number, against: number?): string
		if not against then
			return `{math.floor(value + 0.5)}`
		end
		local diff = math.floor(value + 0.5) - math.floor(against + 0.5)
		if diff > 0 then
			return `{math.floor(value + 0.5)} <font color="#{UP:ToHex()}">▲ +{diff}</font>`
		elseif diff < 0 then
			return `{math.floor(value + 0.5)} <font color="#{DOWN:ToHex()}">▼ {diff}</font>`
		end
		return `{math.floor(value + 0.5)}`
	end

	local function showDetails()
		for _, child in big:GetChildren() do
			child:Destroy()
		end
		local saved = selected and snapshot.Items[selected]
		local visible = saved ~= nil
		for _, child in { name, kind, stats, equip, sell } do
			child.Visible = visible
		end
		empty.Visible = not visible
		if not saved or not selected then
			return
		end
		local def = Items.Defs[saved.Item]
		local info = Rarity.Info[saved.Rarity] or Rarity.Info.Common
		local upgrade = saved.Upgrade or 0
		preview(big, saved, UDim2.fromScale(1, 1), UDim2.new())
		name.Text = Items.NameFor(saved.Item, saved.Rarity) .. (if upgrade > 0 then ` +{upgrade}` else "")
		name.TextColor3 = info.Color
		local gear = Items.IsGear(saved.Item)
		local set = def and def.Set and Armor.SetByName[def.Set]
		kind.Text = if def and def.WeaponType then `{saved.Rarity} {def.WeaponType}`
			elseif set then `{saved.Rarity} {set.Kind} · {def.Slot}`
			elseif def and def.Set == "Ring" then `{saved.Rarity} Ring`
			elseif def then def.Slot
			else saved.Rarity
		kind.TextColor3 = if gear then info.Color else Color3.fromRGB(190, 180, 165)
		if not gear then
			name.TextColor3 = TEXT
			local count = saved.Count or 1
			stats.Text = `{(def and def.Description) or ""}\nYou have {count}.`
			equip.Visible = false
			sell.Visible = not (def and def.Keepsake)
			local price = Items.SellPrice(saved.Item, saved.Rarity, 0, count)
			if player:GetAttribute("AtShop") then
				sell.Text = if confirmSell then `Sure? Sell all for {price}` else `Sell all ({price} gold)`
				sell.BackgroundColor3 = if confirmSell then Color3.fromRGB(130, 40, 30) else Color3.fromRGB(80, 55, 25)
			else
				sell.Text = if confirmSell then "Sure? Drop them all" else "Drop all"
				sell.BackgroundColor3 = if confirmSell then Color3.fromRGB(130, 40, 30) else Color3.fromRGB(70, 40, 40)
			end
			return
		end

		if def and def.Set then
			local wornId = snapshot.Equipped[def.Slot]
			local current = wornId and wornId ~= selected and snapshot.Items[wornId] or nil
			local mine = Armor.StatsOf(saved.Item, saved.Rarity, upgrade)
			local theirs = current and Armor.StatsOf(current.Item, current.Rarity, current.Upgrade or 0)
			local lines = { `Defense {compare(mine.Defense, theirs and theirs.Defense)}` }
			if mine.Health > 0 or (theirs and theirs.Health > 0) then
				table.insert(lines, `Health +{compare(mine.Health, theirs and theirs.Health)}`)
			end
			if mine.Speed ~= 0 then
				table.insert(lines, `Speed {if mine.Speed > 0 then "+" else ""}{math.floor(mine.Speed * 100 + 0.5)}%`)
			end
			if mine.SpellPower > 0 then
				table.insert(lines, `Spell power +{compare(mine.SpellPower * 100, theirs and theirs.SpellPower * 100)}%`)
			end
			stats.Text = table.concat(lines, "\n")
			local worn = wornId == selected
			equip.Text = if worn then "Take off" else "Wear"
			equip.AutoButtonColor = true
			equip.BackgroundColor3 = if worn then Color3.fromRGB(70, 55, 40) else Color3.fromRGB(40, 70, 45)
			local armorPrice = Items.SellPrice(saved.Item, saved.Rarity, upgrade)
			sell.Visible = not worn
			if player:GetAttribute("AtShop") then
				sell.Text = if confirmSell then `Sure? Sell for {armorPrice}` else `Sell ({armorPrice} gold)`
				sell.BackgroundColor3 = if confirmSell then Color3.fromRGB(130, 40, 30) else Color3.fromRGB(80, 55, 25)
			else
				sell.Text = if confirmSell then "Sure? Drop it for good" else "Drop"
				sell.BackgroundColor3 = if confirmSell then Color3.fromRGB(130, 40, 30) else Color3.fromRGB(70, 40, 40)
			end
			return
		end

		-- Compared with the weapon in hand (unless this is it).
		local equippedId = snapshot.Equipped.Weapon
		local current = equippedId and equippedId ~= selected and snapshot.Items[equippedId] or nil
		local damage = Items.WeaponDamage(saved.Item, saved.Rarity, upgrade)
		local heal = Items.WeaponHeal(saved.Item, saved.Rarity, upgrade)
		local lines = { `Damage {compare(damage, current and Items.WeaponDamage(current.Item, current.Rarity, current.Upgrade or 0))}` }
		if heal > 0 then
			table.insert(lines, `Heal {compare(heal, current and Items.WeaponHeal(current.Item, current.Rarity, current.Upgrade or 0))}`)
		end
		stats.Text = table.concat(lines, "\n")

		local isEquipped = equippedId == selected
		equip.Text = if isEquipped then "Equipped" else "Equip"
		equip.AutoButtonColor = not isEquipped
		equip.BackgroundColor3 = if isEquipped then Color3.fromRGB(45, 45, 45) else Color3.fromRGB(40, 70, 45)
		local price = Items.SellPrice(saved.Item, saved.Rarity, upgrade)
		sell.Visible = not isEquipped
		if player:GetAttribute("AtShop") then
			sell.Text = if confirmSell then `Sure? Sell for {price}` else `Sell ({price} gold)`
			sell.BackgroundColor3 = if confirmSell then Color3.fromRGB(130, 40, 30) else Color3.fromRGB(80, 55, 25)
		else
			sell.Text = if confirmSell then "Sure? Drop it for good" else "Drop"
			sell.BackgroundColor3 = if confirmSell then Color3.fromRGB(130, 40, 30) else Color3.fromRGB(70, 40, 40)
		end
	end

	local function redraw()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local ids = sortedIds()
		title.Text = `Bag  {#ids}/{snapshot.BagSize}`
		for order = 1, snapshot.BagSize do
			local id = ids[order]
			local cell = Instance.new("Frame")
			cell.Name = `Slot{order}`
			cell.BackgroundColor3 = SLOT
			cell.LayoutOrder = order
			cell.Parent = grid
			corner(cell, 6)
			if not id then
				stroke(cell, Color3.fromRGB(55, 48, 46), 1)
				continue
			end
			local saved = snapshot.Items[id]
			local info = Rarity.Info[saved.Rarity] or Rarity.Info.Common
			cell.BackgroundColor3 = SLOT:Lerp(info.Color, 0.18)
			stroke(cell, info.Color, if selected == id then 3 else 1.5)
			preview(cell, saved, UDim2.fromScale(1, 1), UDim2.new())
			if (saved.Count or 1) > 1 then
				local count = label(cell, Fonts.Number, 15, TEXT)
				count.AnchorPoint = Vector2.new(1, 1)
				count.Position = UDim2.new(1, -4, 1, -2)
				count.Size = UDim2.fromOffset(40, 16)
				count.TextXAlignment = Enum.TextXAlignment.Right
				count.TextStrokeTransparency = 0.2
				count.ZIndex = 2
				count.Text = `x{saved.Count}`
			end
			if isWorn(id) then
				local badge = label(cell, Fonts.Title, 14, GOLD)
				badge.Position = UDim2.fromOffset(4, 2)
				badge.Size = UDim2.fromOffset(20, 16)
				badge.Text = "E"
			end
			-- a clear button over the picture takes the click (the 3D view would swallow it)
			local hit = Instance.new("TextButton")
			hit.Name = "Pick"
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 3
			hit.Parent = cell
			hit.Activated:Connect(function()
				selected = id
				confirmSell = false
				redraw()
			end)
		end
		showDetails()
	end

	local function setOpen(shown: boolean)
		panel.Visible = shown
		if shown then
			dot.Visible = false
			local screen = workspace.CurrentCamera.ViewportSize
			fit.Scale = math.min(1, (screen.X - 24) / panel.Size.X.Offset, (screen.Y - 90) / panel.Size.Y.Offset)
			redraw()
		else
			selected = nil
			confirmSell = false
		end
	end

	open.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	opener = function()
		setOpen(true)
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)
	equip.Activated:Connect(function()
		local saved = selected and snapshot.Items[selected]
		local def = saved and Items.Defs[saved.Item]
		if selected and def and def.Set then
			actionRemote:FireServer(if snapshot.Equipped[def.Slot] == selected then "Unequip" else "Equip", selected)
		elseif selected and snapshot.Equipped.Weapon ~= selected then
			actionRemote:FireServer("Equip", selected)
		end
	end)
	sell.Activated:Connect(function()
		local saved = selected and snapshot.Items[selected]
		if not saved or not selected then
			return
		end
		local precious = if Items.IsGear(saved.Item)
			then (RARITY_RANK[saved.Rarity] or 0) >= (RARITY_RANK.Epic or 3)
			else (saved.Count or 1) >= 5
		if precious and not confirmSell then
			confirmSell = true
			showDetails()
			return
		end
		actionRemote:FireServer(if player:GetAttribute("AtShop") then "Sell" else "Drop", selected)
		selected = nil
		confirmSell = false
	end)
	player:GetAttributeChangedSignal("AtShop"):Connect(function()
		confirmSell = false
		if panel.Visible then
			showDetails()
		end
	end)
	ContextActionService:BindAction("ToggleBag", function(_, state)
		if state == Enum.UserInputState.Begin then
			setOpen(not panel.Visible)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	Remotes.Event("InventoryUpdated").OnClientEvent:Connect(function(newSnapshot: Snapshot)
		snapshot = newSnapshot
		if selected and not snapshot.Items[selected] then
			selected = nil
		end
		if panel.Visible then
			redraw()
		end
	end)
	Remotes.Event("ItemReceived").OnClientEvent:Connect(function()
		if not panel.Visible then
			dot.Visible = true
		end
	end)
end

return Inventory
