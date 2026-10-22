--!strict
-- Which kind of screen the player is on, for laying the UI out (client only).
--   Touch: a phone or tablet (touch, no keyboard): big buttons, things kept clear of the thumb sticks
--   Small: the screen is short (a phone held sideways): panels scale down to fit

local UserInputService = game:GetService("UserInputService")

local Device = {}

function Device.Touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Device.Small(): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y < 500
end

return Device
