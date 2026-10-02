--!strict
-- Client entry point: builds the UI and listens to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.UI.Hud)

Hud.Start()

Remotes.Event("Notify").OnClientEvent:Connect(function(text: string)
	Hud.ShowMessage(text, 8)
end)
