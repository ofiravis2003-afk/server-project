--!strict
-- The single list of every client <-> server remote.
-- The server creates them on startup; the client waits for them.
-- Rule: the client only *asks*. The server checks everything and decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"Notify", -- server -> client: show a message on screen
	"StatsUpdated", -- server -> client: level, XP and gold changed
	"DamageNumber", -- server -> client: show a floating number (damage, poison, rewards)
	"Effect", -- server -> client: draw an arrow, fireball or blast
	"Attack", -- client -> server: swing / shoot the held weapon in a direction
	"RunUpdated", -- server -> client: the current floor and the keys in hand
	"FloorStarted", -- server -> client: a new floor begins (shows its title)
	"ItemReceived", -- server -> client: the player got a new item (shows the "New item!" card)
	"BossIntro", -- server -> client: play a boss's entrance scene (camera, its words, its name)
	"InventoryUpdated", -- server -> client: everything in the player's bag and what is equipped
	"InventoryAction", -- client -> server: equip or sell an item from the bag
	"FloorPicker", -- server -> client: open the floor picker (the floors this player can choose)
	"ChooseFloor", -- client -> server: start the run on this floor (checked against the player's progress)
	"ShopOpen", -- server -> client: open a shopkeeper's window (its stock), or nil to close it
	"ShopBuy", -- client -> server: buy offer number N from the open shop
	"ShopClose", -- client -> server: the player closed the shop window
	"UpgradeItem", -- client -> server: ask Brakka to upgrade this weapon (by item id)
	"UpgradeResult", -- server -> client: how the upgrade went (success, the new level, or failed)
	"DialogueOpen", -- server -> client: talk to this townsperson (their model)
	"DialogueAction", -- client -> server: the townsperson's own button (e.g. Brakka's Trade)
	"QuestsUpdated", -- server -> client: every quest's state and progress, rank points and rank
	"QuestAction", -- client -> server: Accept / TurnIn / Abandon a quest (only at the Guild)
	"QuestBoardOpen", -- server -> client: open the quest board window
	"Traveling", -- server -> client: the player is about to teleport (where to), show the travel card
	"LoreShow", -- server -> client: show a page of Ilvane's journal (its id, and how many the player has found)
}

local FUNCTION_NAMES = {}

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
