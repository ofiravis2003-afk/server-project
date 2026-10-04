--!strict
-- The single list of every client <-> server remote.
-- The server creates them on startup; the client waits for them.
-- Rule: the client only *asks*. The server checks everything and decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"Notify", -- server -> client: show a message on screen
	"NestsUpdated", -- server -> client: the eggs in the player's nests changed
	"DragonsUpdated", -- server -> client: the player's dragon collection changed
	"QuestUpdated", -- server -> client: the current tutorial quest and its progress
	"ShowDialog", -- server -> client: Elder Ember says some lines
}

local FUNCTION_NAMES = {
	"HatchEgg", -- client -> server: hatch the egg in nest N, returns the new dragon
	"DragonAction", -- client -> server: Activate / Deactivate / Lock / Unlock / Sell a dragon
	"BreedDragons", -- client -> server: breed two dragons into a Bred Egg
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTION_NAMES do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
