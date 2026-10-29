--!strict
-- Waves the flags on the town's towers (TownBanners tags them "TownFlag" and leaves each one's hinge on the pole
-- as an attribute): every flag swings round its pole in the wind and flutters, each on its own beat. Moved here on
-- the client only, so the server sends nothing for it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TownFlags = {}

type Flag = { Part: BasePart, Hinge: CFrame, Phase: number }

function TownFlags.Start()
	local flags: { Flag } = {}
	local rng = Random.new()
	local function add(part: Instance)
		local hinge = part:GetAttribute("Hinge")
		if part:IsA("BasePart") and typeof(hinge) == "CFrame" then
			table.insert(flags, { Part = part, Hinge = hinge, Phase = rng:NextNumber(0, math.pi * 2) })
		end
	end
	for _, part in CollectionService:GetTagged("TownFlag") do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("TownFlag"):Connect(add)

	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		for _, f in flags do
			if not f.Part.Parent then
				continue
			end
			local swing = math.sin(t * 0.9 + f.Phase) * 0.3 + math.sin(t * 4.7 + f.Phase * 2) * 0.06
			local length = f.Part.Size.Y -- (the cloth lies on its side: its height is the flag's length)
			f.Part.CFrame = f.Hinge * CFrame.Angles(0, swing, 0) * CFrame.new(length / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
	end)
end

return TownFlags
