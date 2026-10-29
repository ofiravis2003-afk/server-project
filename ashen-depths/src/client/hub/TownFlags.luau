--!strict
-- Waves the flags on the town's towers. TownBanners leaves each flag as one flat cloth (tagged "TownFlag", its
-- hinge on the pole as an attribute); here it is cut into strips along its length, each strip showing its slice
-- of the picture (a Texture offset along the flag), and a ripple runs down the strips from the pole to the tail,
-- growing toward the free end, while the whole flag swings a little in the wind. Done on the client only, so the
-- server sends nothing for it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local STRIPS = 10
local FAR = 220 -- past this distance a flag stops being animated

local TownFlags = {}

type Flag = { Hinge: CFrame, Length: number, Strips: { BasePart }, Phase: number }

local function cutIntoStrips(cloth: BasePart, folder: Folder): Flag?
	local hinge = cloth:GetAttribute("Hinge")
	local decal = cloth:FindFirstChildOfClass("Decal")
	if typeof(hinge) ~= "CFrame" or not decal then
		return nil
	end
	-- the cloth lies on its side: its height (Y) is the flag's length, its width (X) the flag's height
	local length, height = cloth.Size.Y, cloth.Size.X
	local seg = length / STRIPS
	local strips = {}
	for j = 0, STRIPS - 1 do
		local p = Instance.new("Part")
		p.Name = "FlagStrip"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		-- a hair longer than its slice so no gaps open when neighbours bend apart
		p.Size = Vector3.new(height, seg * (if j < STRIPS - 1 then 1.06 else 1), 0.05)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local t = Instance.new("Texture")
			t.Texture = decal.Texture
			t.Face = face
			t.StudsPerTileU = height
			t.StudsPerTileV = length
			t.OffsetStudsV = j * seg
			t.Parent = p
		end
		p.Parent = folder
		table.insert(strips, p)
	end
	-- the flat original stays (for anyone without this script) but hidden here
	for _, d in cloth:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	return { Hinge = hinge, Length = length, Strips = strips, Phase = math.random() * math.pi * 2 }
end

function TownFlags.Start()
	local folder = Instance.new("Folder")
	folder.Name = "WavingFlags"
	folder.Parent = workspace
	local flags: { Flag } = {}
	local function add(cloth: Instance)
		if cloth:IsA("BasePart") then
			local flag = cutIntoStrips(cloth, folder)
			if flag then
				table.insert(flags, flag)
			end
		end
	end
	for _, cloth in CollectionService:GetTagged("TownFlag") do
		add(cloth)
	end
	CollectionService:GetInstanceAddedSignal("TownFlag"):Connect(add)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for _, f in flags do
			if (f.Hinge.Position - eye).Magnitude > FAR then
				continue
			end
			local seg = f.Length / STRIPS
			-- the whole flag swings slowly round its pole; then each strip bends a little more than the last
			local angle = math.sin(t * 0.7 + f.Phase) * 0.25
			local at = Vector3.zero
			for j, strip in f.Strips do
				local k = (j - 1) / (STRIPS - 1)
				angle += math.sin(t * 5.5 - j * 0.75 + f.Phase) * (0.06 + 0.16 * k)
				local dir = Vector3.new(math.cos(angle), 0, -math.sin(angle))
				local centre = at + dir * (seg / 2)
				strip.CFrame = f.Hinge * CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(90))
				at += dir * seg
			end
		end
	end)
end

return TownFlags
