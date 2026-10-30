--[[
	TouchBus  (ModuleScript)  ->  ReplicatedStorage/Spellshot/TouchBus

	The one wire between the on-screen touch buttons (TouchControls) and the scripts that own the actions.
	A button going down or up is fired here as (action, down); the owner of that action listens and runs the
	same code its key runs:

		"M1"                                          SpellshotInput (the mouse button), RadiantClient (Light Lance's hold)
		"Primary" "Mobility" "Defense" "Ultimate"     SpellshotInput (that role's key)
		"Jump" "Crouch"                               MovementController (Space, and the crouch / slide key)
		"CrouchClear"                                 MovementController: a one-off (drop a Toggle Crouch latch); never
		                                              held, so TouchControls clears its Down flag at once (2026-10-19)

	A module rather than an Instance in the tree so there is exactly one per client whichever script asks first.
]]

local Bus = {}

local event = Instance.new("BindableEvent")
Bus.Event = event.Event

-- [action] = true while that button is held
Bus.Down = {}

function Bus.Fire(action, down)
	Bus.Down[action] = down and true or nil
	event:Fire(action, down and true or false)
end

return Bus
