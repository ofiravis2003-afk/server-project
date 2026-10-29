--!strict
-- Emberhold's colours: the town's red-and-gold banner (the crossed swords over the flame on the well's rim) hung
-- on the inner face of every wall tower and either side of the gate, a flag flying from the top of each tower,
-- iron torches burning along the inside of the wall, and strings of bunting over the plaza and the Market Square.
-- Runs on the finished town (after TownBuilder spread it out and set it on the ground), finding the towers, the
-- wall and the gatehouse by name and their faces by ray, so it fits whatever size the Tripo props come in.
-- The flags are tagged "TownFlag" and waved by the client (TownFlags), so the server sends nothing per frame.

local CollectionService = game:GetService("CollectionService")

local BANNER = "rbxassetid://79992070057290" -- tools/logo/banner_emberwell.png
local PENNANT = "rbxassetid://105400265779631" -- tools/logo/pennant_emberwell.png

local CRIMSON = Color3.fromRGB(122, 22, 26)
local GOLD = Color3.fromRGB(206, 160, 70)
local CREAM = Color3.fromRGB(226, 210, 176)
local IRON = Color3.fromRGB(34, 32, 32)
local WOOD = Color3.fromRGB(62, 42, 28)
local WARM = Color3.fromRGB(255, 170, 90)

local TownBanners = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The cloth: an unseen board with the banner picture on both faces (the picture's own edges are see-through).
local function cloth(parent: Instance, name: string, image: string, size: Vector2, cframe: CFrame): Part
	local board = part(parent, name, Vector3.new(size.X, size.Y, 0.1), cframe, CRIMSON, Enum.Material.Fabric)
	board.Transparency = 1
	board.CastShadow = false
	board.CanQuery = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Texture = image
		decal.Face = face
		decal.Parent = board
	end
	return board
end

-- Where a ray from `from` toward `to` first meets `target` (nil if it misses).
local function surface(target: Instance, from: Vector3, to: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { target }
	local hit = workspace:Raycast(from, to - from, params)
	return hit and hit.Position
end

-- A banner hanging from an iron rod with gold ends, its top at `top`, facing `out` (the way it is seen from).
local function hangBanner(parent: Instance, top: Vector3, out: Vector3, width: number)
	local height = width * 2.5
	local frame = CFrame.lookAt(top, top + out)
	part(parent, "BannerRod", Vector3.new(width + 1.4, 0.3, 0.3), frame * CFrame.new(0, 0, -0.3), IRON, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part(parent, "BannerFinial", Vector3.new(0.6, 0.6, 0.6), frame * CFrame.new(side * (width / 2 + 0.8), 0, -0.3), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	end
	cloth(parent, "Banner", BANNER, Vector2.new(width, height), frame * CFrame.new(0, -height / 2 + 0.2, -0.45))
end

-- A flag on a pole standing on `base`, the cloth tagged so the client waves it.
local function flagPole(parent: Instance, base: Vector3, poleHeight: number)
	part(parent, "FlagPole", Vector3.new(poleHeight, 0.35, 0.35), CFrame.new(base + Vector3.new(0, poleHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(parent, "FlagTop", Vector3.new(0.7, 0.7, 0.7), CFrame.new(base + Vector3.new(0, poleHeight + 0.2, 0)), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	-- the flag flies out sideways from the pole: its long side along the wind (X), hinged on the pole
	local w, h = 7, 3.6
	local hinge = CFrame.new(base + Vector3.new(0, poleHeight - h / 2 - 0.3, 0)) * CFrame.Angles(0, math.rad(30), 0)
	local flag = cloth(parent, "Flag", PENNANT, Vector2.new(h, w), hinge * CFrame.new(w / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(90)))
	flag:SetAttribute("Hinge", hinge)
	CollectionService:AddTag(flag, "TownFlag")
end

-- An iron torch bracket on the wall: an arm out of the stone, a cup, a flame and its warm light.
local function torch(parent: Instance, at: Vector3, out: Vector3)
	local frame = CFrame.lookAt(at, at + out)
	part(parent, "TorchPlate", Vector3.new(0.9, 1.4, 0.2), frame, IRON, Enum.Material.Metal)
	part(parent, "TorchArm", Vector3.new(0.25, 0.25, 1.4), frame * CFrame.new(0, 0, -0.7) * CFrame.Angles(math.rad(-25), 0, 0), IRON, Enum.Material.Metal)
	local cup = part(parent, "TorchCup", Vector3.new(0.8, 0.6, 0.8), frame * CFrame.new(0, 0.5, -1.4), IRON, Enum.Material.Metal)
	local flame = Instance.new("ParticleEmitter")
	flame.LightEmission = 1
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 150)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 40, 20)),
	})
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flame.Lifetime = NumberRange.new(0.4, 0.7)
	flame.Rate = 30
	flame.Speed = NumberRange.new(2, 3.5)
	flame.SpreadAngle = Vector2.new(12, 12)
	flame.EmissionDirection = Enum.NormalId.Top
	flame.Parent = cup
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = cup
end

-- A string of triangular pennants from `a` to `b`, sagging in the middle, in turn crimson, gold and cream.
local function bunting(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local span = (b - a).Magnitude
	local count = math.max(3, math.floor(span / 2.4))
	local colors = { CRIMSON, GOLD, CREAM }
	local function point(t: number): Vector3
		return a + (b - a) * t - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	for i = 0, count - 1 do
		local p0, p1 = point(i / count), point((i + 1) / count)
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude
		part(parent, "BuntingCord", Vector3.new(0.08, 0.08, len), CFrame.lookAt(mid, p1), Color3.fromRGB(90, 70, 50), Enum.Material.Fabric)
		-- a pennant hangs from the middle of each length of cord: two wedges back to back make the triangle
		local along = (p1 - p0).Unit
		local frame = CFrame.fromMatrix(mid, along, Vector3.yAxis, along:Cross(Vector3.yAxis))
		local width, drop = len * 0.8, 1.7
		for _, side in { -1, 1 } do
			local w = Instance.new("WedgePart")
			w.Name = "Pennant"
			w.Anchored = true
			w.CanCollide = false
			w.CanTouch = false
			w.CanQuery = false
			w.CastShadow = false
			w.Material = Enum.Material.Fabric
			w.Color = colors[i % #colors + 1]
			w.Size = Vector3.new(0.05, drop, width / 2)
			-- each wedge's slope runs from the cord down to the tip in the middle
			w.CFrame = frame * CFrame.new(side * width / 4, -drop / 2, 0) * CFrame.Angles(0, math.rad(90 * side), 0) * CFrame.Angles(math.pi, 0, 0)
			w.Parent = parent
		end
	end
end

function TownBanners.Decorate(town: Model)
	local folder = Instance.new("Folder")
	folder.Name = "TownBanners"
	folder.Parent = town
	local center = (town:FindFirstChild("GreatWell", true) :: Model?) and (town:FindFirstChild("GreatWell", true) :: Model):GetPivot().Position
		or town:GetPivot().Position
	local function inward(at: Vector3): Vector3
		return Vector3.new(center.X - at.X, 0, center.Z - at.Z).Unit
	end

	local sections = 0
	for _, piece in town:GetChildren() do
		if not piece:IsA("Model") then
			continue
		end
		local box, size = piece:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		if piece.Name == "WallTower" then
			local inn = inward(box.Position)
			-- the banner hangs on the tower's inner face, a little above the wall walk
			local y = bottom + size.Y * 0.62
			local probe = Vector3.new(box.Position.X, y, box.Position.Z)
			local face = surface(piece, probe + inn * (size.X + 10), probe)
			if face then
				hangBanner(folder, face + inn * 0.4, inn, 4.2)
			end
			-- the flag flies from the very top
			flagPole(folder, Vector3.new(box.Position.X, bottom + size.Y - 0.6, box.Position.Z), 9)
		elseif piece.Name == "Gatehouse" then
			local inn = inward(box.Position)
			local across = Vector3.new(-inn.Z, 0, inn.X)
			for _, side in { -1, 1 } do
				local probe = box.Position + across * side * size.X * 0.3 + Vector3.new(0, size.Y * 0.18, 0)
				local face = surface(piece, probe + inn * (size.Z + 10), probe)
				if face then
					hangBanner(folder, face + inn * 0.4, inn, 5.5)
				end
			end
		elseif piece.Name == "TownWall" then
			-- a torch on every other section, a bit above head height, on the inner face
			sections += 1
			if sections % 2 == 1 then
				continue
			end
			local inn = inward(box.Position)
			local probe = Vector3.new(box.Position.X, bottom + math.min(9, size.Y * 0.6), box.Position.Z)
			local face = surface(piece, probe + inn * (size.Z + 10), probe)
			if face then
				torch(folder, face + inn * 0.1, inn)
			end
		end
	end

	-- bunting across the plaza and over the Market Square, from lamp post to lamp post
	local lamps = {}
	for _, piece in town:GetChildren() do
		if piece.Name == "LampPost" and piece:IsA("Model") then
			local box, size = piece:GetBoundingBox()
			table.insert(lamps, Vector3.new(box.Position.X, box.Position.Y + size.Y / 2 - 2.2, box.Position.Z))
		end
	end
	local used: { [Vector3]: boolean } = {}
	for _, a in lamps do
		-- string each post to its nearest neighbour that is a sensible span away (not one already strung to it)
		local best, bestDist = nil, math.huge
		for _, b in lamps do
			local d = (b - a).Magnitude
			if b ~= a and not used[b] and d > 14 and d < 52 and d < bestDist then
				best, bestDist = b, d
			end
		end
		if best then
			used[a] = true
			bunting(folder, a, best, bestDist * 0.07)
		end
	end
end

return TownBanners
