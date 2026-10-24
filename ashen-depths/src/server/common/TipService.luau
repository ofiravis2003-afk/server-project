--!strict
-- Shows a player a tip (shared/Tips) the first time its moment comes, and never again (data.Tips).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tips = require(ReplicatedStorage.Shared.Tips)
local DataService = require(script.Parent.DataService)

local TipService = {}

local tipRemote = Remotes.Event("Tip")

function TipService.Show(player: Player, id: string)
	local data = DataService.GetData(player)
	if not data or not (Tips :: any)[id] then
		return
	end
	data.Tips = data.Tips or {}
	if data.Tips[id] then
		return
	end
	data.Tips[id] = true
	tipRemote:FireClient(player, id)
end

return TipService
