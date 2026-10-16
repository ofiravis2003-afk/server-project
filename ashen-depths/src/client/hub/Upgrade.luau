--!strict
-- Brakka's upgrade window: the player's weapons on the left; the chosen one's level now and next, its damage
-- before and after, what it costs (each material shown as "have / need", green when there's enough, red when
-- not), the chance it holds, and the Upgrade button. The result flashes up: success, or the loss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarity = require(ReplicatedStorage.Shared.Rarity)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local PANEL = Color3.fromRGB(22, 18, 20)
local EDGE = Color3.fromRGB(120, 90, 50)
local TEXT = Color3.fromRGB(230, 222, 208)
local GOLD = Color3.fromRGB(240, 190, 90)
local GOOD = Color3.fromRGB(110, 220, 120)
local BAD = Color3.fromRGB(235, 90, 80)
local ROW = Color3.fromRGB(36, 30, 30)

type SavedItem = { Item: string, Rarity: string, Upgrade: number?, Count: number? }
type Snapshot = { Items: { [string]: SavedItem }, Equipped: { [string]: string }, BagSize: number }

local Upgrade = {}

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

local function picture(parent: Instance, saved: SavedItem, size: number, position: UDim2)
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromOffset(size, size)
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
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(distance * 0.55, distance * 0.3, -distance * 0.8), box.Position)
end

local function nameOf(saved: SavedItem): string
	local level = saved.Upgrade or 0
	return Items.NameFor(saved.Item, saved.Rarity) .. (if level > 0 then ` +{level}` else "")
end

function Upgrade.Start()
	local player = Players.LocalPlayer
	local upgradeRemote = Remotes.Event("UpgradeItem")
	local snapshot: Snapshot = { Items = {}, Equipped = {}, BagSize = 30 }
	local selected: string? = nil
	local busy = false
	local gold = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "Upgrade"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 410, 0.5, 0)
	panel.Size = UDim2.fromOffset(560, 470)
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
	title.Text = "Upgrade a weapon"
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
	close.FontFace = Fonts.Title
	close.TextSize = 18
	close.TextColor3 = TEXT
	close.Text = "X"
	close.Parent = panel
	corner(close, 6)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 50)
	list.Size = UDim2.new(0, 220, 1, -62)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local detail = Instance.new("Frame")
	detail.Position = UDim2.fromOffset(242, 50)
	detail.Size = UDim2.new(1, -254, 1, -62)
	detail.BackgroundColor3 = ROW
	detail.Parent = panel
	corner(detail, 8)

	local result = label(panel, Fonts.Title, 30, GOOD)
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.new(0.5, 110, 0.5, 0)
	result.Size = UDim2.fromOffset(300, 40)
	result.TextXAlignment = Enum.TextXAlignment.Center
	result.TextTransparency = 1
	result.TextStrokeTransparency = 1
	result.ZIndex = 5

	local function weaponIds(): { string }
		local ids = {}
		for id, saved in snapshot.Items do
			local def = Items.Defs[saved.Item]
			if def and def.Slot == "Weapon" then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			local ea, eb = snapshot.Equipped.Weapon == a, snapshot.Equipped.Weapon == b
			if ea ~= eb then
				return ea
			end
			return (snapshot.Items[a].Upgrade or 0) > (snapshot.Items[b].Upgrade or 0)
		end)
		return ids
	end

	local function count(itemName: string): number
		local n = 0
		for _, saved in snapshot.Items do
			if saved.Item == itemName then
				n += saved.Count or 1
			end
		end
		return n
	end

	local redraw: () -> ()

	local function showDetail()
		for _, child in detail:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local saved = selected and snapshot.Items[selected]
		if not saved or not selected then
			local hint = label(detail, Fonts.Body, 16, Color3.fromRGB(160, 150, 140))
			hint.Size = UDim2.fromScale(1, 1)
			hint.TextXAlignment = Enum.TextXAlignment.Center
			hint.Text = "Choose a weapon"
			return
		end
		local info = Rarity.Info[saved.Rarity] or Rarity.Info.Common
		local level = saved.Upgrade or 0
		picture(detail, saved, 90, UDim2.fromOffset(8, 8))
		local name = label(detail, Fonts.Title, 20, info.Color)
		name.Position = UDim2.fromOffset(106, 12)
		name.Size = UDim2.new(1, -114, 0, 24)
		name.TextScaled = true
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 20
		nameLimit.Parent = name
		name.Text = nameOf(saved)
		if level >= Upgrades.Max then
			local done = label(detail, Fonts.Body, 16, GOLD)
			done.Position = UDim2.fromOffset(106, 42)
			done.Size = UDim2.new(1, -114, 0, 40)
			done.TextWrapped = true
			done.Text = "Fully upgraded. Even Brakka can't do better."
			return
		end
		local nowDamage = math.floor(Items.WeaponDamage(saved.Item, saved.Rarity, level) + 0.5)
		local nextDamage = math.floor(Items.WeaponDamage(saved.Item, saved.Rarity, level + 1) + 0.5)
		local step = label(detail, Fonts.Body, 16, TEXT)
		step.Position = UDim2.fromOffset(106, 42)
		step.Size = UDim2.new(1, -114, 0, 44)
		step.RichText = true
		step.TextWrapped = true
		step.TextYAlignment = Enum.TextYAlignment.Top
		step.Text = `+{level}  →  <font color="#{GOOD:ToHex()}">+{level + 1}</font>\nDamage {nowDamage}  →  <font color="#{GOOD:ToHex()}">{nextDamage}</font>`

		local cost = Upgrades.Cost(saved.Rarity, level + 1)
		local y = 110
		local enough = true
		local function costLine(text: string, ok: boolean)
			local line = label(detail, Fonts.Body, 15, if ok then GOOD else BAD)
			line.Position = UDim2.fromOffset(14, y)
			line.Size = UDim2.new(1, -28, 0, 20)
			line.Text = text
			y += 22
			if not ok then
				enough = false
			end
		end
		costLine(`Gold: {gold} / {cost.Gold}`, gold >= cost.Gold)
		for _, need in cost.Materials do
			local have = count(need.Item)
			costLine(`{Items.Defs[need.Item].DisplayName}: {have} / {need.Count}`, have >= need.Count)
		end
		y += 6
		local chance = label(detail, Fonts.Body, 15, if cost.Chance < 1 then Color3.fromRGB(235, 200, 120) else TEXT)
		chance.Position = UDim2.fromOffset(14, y)
		chance.Size = UDim2.new(1, -28, 0, 40)
		chance.TextWrapped = true
		chance.TextYAlignment = Enum.TextYAlignment.Top
		chance.Text = if cost.Chance < 1
			then `Chance it holds: {math.floor(cost.Chance * 100 + 0.5)}%. If it fails, the gold and materials are lost (the weapon stays).`
			else "This one always holds."

		local go = Instance.new("TextButton")
		go.AnchorPoint = Vector2.new(0.5, 1)
		go.Position = UDim2.new(0.5, 0, 1, -12)
		go.Size = UDim2.new(1, -28, 0, 42)
		go.BackgroundColor3 = if enough then Color3.fromRGB(150, 90, 30) else Color3.fromRGB(55, 50, 48)
		go.AutoButtonColor = enough
		go.FontFace = Fonts.Title
		go.TextSize = 20
		go.TextColor3 = TEXT
		go.Text = if enough then "Upgrade" else "Not enough materials"
		go.Parent = detail
		corner(go, 6)
		stroke(go, EDGE, 1.5)
		go.Activated:Connect(function()
			if enough and not busy and selected then
				busy = true
				upgradeRemote:FireServer(selected)
				task.delay(1, function()
					busy = false
				end)
			end
		end)
	end

	redraw = function()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, id in weaponIds() do
			local saved = snapshot.Items[id]
			local info = Rarity.Info[saved.Rarity] or Rarity.Info.Common
			local row = Instance.new("TextButton")
			row.Text = ""
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -8, 0, 50)
			row.BackgroundColor3 = if selected == id then ROW:Lerp(info.Color, 0.25) else ROW
			row.Parent = list
			corner(row, 8)
			stroke(row, info.Color, if selected == id then 2.5 else 1)
			picture(row, saved, 42, UDim2.fromOffset(4, 4))
			local name = label(row, Fonts.Title, 15, info.Color)
			name.Position = UDim2.fromOffset(50, 4)
			name.Size = UDim2.new(1, -56, 0, 22)
			name.TextScaled = true
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 15
			limit.Parent = name
			name.Text = nameOf(saved)
			local sub = label(row, Fonts.Body, 12, Color3.fromRGB(170, 160, 150))
			sub.Position = UDim2.fromOffset(50, 26)
			sub.Size = UDim2.new(1, -56, 0, 18)
			sub.Text = (if snapshot.Equipped.Weapon == id then "Equipped · " else "") .. saved.Rarity
			row.Activated:Connect(function()
				selected = id
				redraw()
			end)
		end
		showDetail()
	end

	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	Remotes.Event("InventoryUpdated").OnClientEvent:Connect(function(newSnapshot: Snapshot)
		snapshot = newSnapshot
		if selected and not snapshot.Items[selected] then
			selected = nil
		end
		if gui.Enabled then
			redraw()
		end
	end)
	Remotes.Event("StatsUpdated").OnClientEvent:Connect(function(stats: any)
		gold = stats.Gold
		if gui.Enabled then
			showDetail()
		end
	end)
	Remotes.Event("UpgradeResult").OnClientEvent:Connect(function(outcome: { Success: boolean, Level: number })
		result.Text = if outcome.Success then `Success! +{outcome.Level}` else "It failed... the materials are lost."
		result.TextColor3 = if outcome.Success then GOOD else BAD
		result.TextTransparency = 0
		result.TextStrokeTransparency = 0.3
		TweenService:Create(result, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.2), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)
	-- the shop closing (walking away) closes this too
	Remotes.Event("ShopOpen").OnClientEvent:Connect(function(shop: any)
		if not shop then
			gui.Enabled = false
		end
	end)

	function Upgrade.Open()
		local screen = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.min(1, (screen.Y - 100) / panel.Size.Y.Offset, (screen.X - 430) / panel.Size.X.Offset)
		gui.Enabled = true
		redraw()
	end
end

function Upgrade.Open() end

return Upgrade
