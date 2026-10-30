--!strict
-- Mira Fell stands in Emberhold only for those who brought her home: everyone else's screen hides her and her Talk
-- prompt (ShopService sets the player's "MiraSaved" attribute from the save).

local Players = game:GetService("Players")

local MiraInTown = {}

function MiraInTown.Start()
	local player = Players.LocalPlayer
	local town = workspace:WaitForChild("Town", 120)
	local mira = town and town:WaitForChild("MiraFell", 20)
	if not mira then
		return
	end
	local function refresh()
		local shown = player:GetAttribute("MiraSaved") == true
		for _, d in mira:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if shown then 0 else 1
				d.CanCollide = false
			elseif d:IsA("ProximityPrompt") then
				d.Enabled = shown
			end
		end
	end
	refresh()
	player:GetAttributeChangedSignal("MiraSaved"):Connect(refresh)
	mira.DescendantAdded:Connect(refresh)
end

return MiraInTown
