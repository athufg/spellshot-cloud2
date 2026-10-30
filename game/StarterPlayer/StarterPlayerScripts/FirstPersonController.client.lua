--[[
	FirstPersonController  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts

	Converts SPELLSHOT from third to first person, and owns the viewmodel's lifecycle.

	ARCHITECTURE: DEDICATED VIEWMODEL. The local character is hidden outright and your camera
	renders a purpose-built pair of arms parented to the Camera instead (see Viewmodel).

	  This is the second answer to this question. The first was camera-at-the-head with the real
	  body drawn, which is beautifully self-consistent and looks wrong: avatar limbs are authored to
	  be read from ten studs away, so at arm's length they eat a third of the frame and your own
	  torso sits across the bottom of the screen. The reference shows two arms and nothing else, at
	  about a third of screen height. That is a viewmodel.

	  The trade that comes with it is real and accepted: first and third person are now two separate
	  animation systems that do NOT mirror each other. Viewmodel animates the arms you see, CastPose
	  animates the body everyone else sees, and each is authored on its own terms against the same
	  facts about what the player is doing. Nothing keeps them frame-identical, and nothing should --
	  a first-person sprint wants the hands low and open where a third-person sprint wants a stride.

	  The real body still exists, still animates and still matters. It is what other players see and
	  what the server hit-registers against; it is simply never what your own camera draws.

	CAMERA: Player.CameraMode = LockFirstPerson keeps Roblox's own camera, which already handles
	mouse lock, gamepad and -- the deciding factor for a mobile-first game -- touch look controls.
	Humanoid.CameraOffset carries both the cast punches and the crouch/slide dip; the Viewmodel owns
	that property and sums the two so neither overwrites the other.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local CastPose = require(iceFolder:WaitForChild("CastPose"))
local Viewmodel = require(iceFolder:WaitForChild("Viewmodel"))

local FIRST_PERSON = true

-- THIRD-PERSON TESTING VIEW (Build Prompt #31)
--   V swaps what the LOCAL player's camera draws: the first-person viewmodel, or the real body seen
--   from a stock-style camera behind it. Nothing else changes. What everyone ELSE sees was always
--   the body -- CastPose has been posing it the whole time, hidden -- so third person shows the
--   third-person animation set that already exists rather than needing a new one.
--
--   LOOK ONLY, and that is the whole point of it. Aiming and hit registration keep the first-person
--   geometry: a shot still leaves your eye, along the camera's look direction, exactly as it does
--   today (see LocalAimCFrame below). This is not tidiness. The server rejects a claimed shot origin
--   more than about 11.6 studs from your Head at a standstill, and this camera sits 12.5 studs back,
--   so a shot fired from the camera would simply stop registering.
--
--   ALLOW_THIRD_PERSON_TOGGLE is the gate, open because an open one is what makes this testable. (2026-10-19: the
--   binding below also requires Config.IsDev, so live players never get it.)
--   Closing it later is this one boolean -- or, for dev accounts only, a single `and
--   player:GetAttribute("Dev") == true` on the binding at the bottom of this file.
--   FLAGGED, NOT DECIDED HERE: free third person in a ranked duel sees around corners and over cover
--   that first person cannot. Whether this ships to every player is a competitive-integrity call for
--   the owner, and nothing in this pass assumes an answer.
local ALLOW_THIRD_PERSON_TOGGLE = true
local TP_KEY = Enum.KeyCode.V
-- How far back and how far off the shoulder the testing camera sits. Framed against the reference
-- the owner supplied (a third-person hero shooter): the body reads at about half the frame height
-- and sits well off centre, so the middle of the screen -- where the crosshair and the enemies are
-- -- stays clear. Roblox's own default is 12.5 and dead behind, which puts your own back over
-- whoever you are shooting at.
local TP_DISTANCE = 7.0
-- studs to the camera's RIGHT, and up. Right shifts the BODY to the left of frame.
local TP_SHOULDER = Vector3.new(3.0, 0.6, 0)
-- Session only, on purpose. A testing view is not a setting, and nothing here writes to the store.
local firstPerson = FIRST_PERSON
-- 90, to match the reference the viewmodel was fitted against. The arms are placed in 3D exactly
-- where RIVALS puts theirs, and a rig fixed in 3D only looks like the reference at the reference's
-- own field of view -- at 70 the same arms would sit 1.4x bigger and closer to the frame edges.
local MIN_FOV = 90

----------------------------------------------------------------------------------------------------
-- camera mode
----------------------------------------------------------------------------------------------------
local camera = workspace.CurrentCamera
-- (2026-10-19, audit P5F-28) the player's Field of View setting owns the FOV (SettingsRuntime binds it): start from it, not
-- a flat 90 that overwrote a saved value SettingsRuntime had already applied when this script ran second. 90 is that
-- setting's default, so an unsaved player still gets the fitted 90.
do
	local okS, S = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	end)
	local fov = okS and type(S) == "table" and tonumber(S.Get("FieldOfView")) or nil
	camera.FieldOfView = fov or MIN_FOV
end

--- Put the Roblox camera into whichever mode `firstPerson` says. Min and Max zoom are set to the
--- same value in both modes so the distance is fixed at what this file asks for rather than at
--- wherever the player last left the scroll wheel.
---
--- THE LIMITS GO FIRST, THE MODE SECOND, and that ordering is the whole thing. Roblox's BaseCamera
--- re-solves the subject distance when CameraMode changes and CLAMPS the result to the zoom limits
--- as they stand at that moment. Set the mode first and the clamp still has the old view's limits,
--- so the camera stays where it was: switching to Classic with Max still 0.5 left the camera 0.6
--- studs from the head, which reads as first person with the arms missing. Measured, not guessed.
---
--- CameraMode is also how the rest of the client finds out which view is on: PyroFX.firstPerson()
--- and Viewmodel both read this property rather than being told, so there is one fact and no wiring.
local function applyCameraMode()
	if not FIRST_PERSON then return end
	if firstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMaxZoomDistance = TP_DISTANCE
		player.CameraMinZoomDistance = TP_DISTANCE
		player.CameraMode = Enum.CameraMode.Classic
	end
end
applyCameraMode()

--- In first person the arms you can see are the viewmodel's, so that is where your own effects have
--- to leave from. In third person those arms are not drawn at all: clearing these two puts the local
--- player back on the ordinary body-welded origin every other character already uses. VFXLibrary
--- reads `LocalMuzzle ~= nil` as "this one is drawn in first person" and takes the RightHand branch
--- otherwise, so nil is not a missing value here, it is the third-person answer.
local function applyMuzzleSources()
	if not (FIRST_PERSON and firstPerson) then
		VFXLibrary.LocalBeamOrigin = nil
		VFXLibrary.LocalMuzzle = nil
		return
	end
	VFXLibrary.LocalBeamOrigin = function()
		return Viewmodel.GetMuzzleCFrame()
	end
	-- either fingertip ("L" / "R"): Cryo Beam's focus sits between your hands and its beam leaves the right one
	VFXLibrary.LocalMuzzle = function(side)
		return Viewmodel.GetMuzzleCFrame(side)
	end
end

--- THE AIM FRAME. Every shot in SpellshotInput starts from `camera.CFrame`, which in first person is
--- your eye. Pull the camera back for the testing view and that same code fires from behind your own
--- back: a different origin, a different ray, and an origin the server will not accept. So the aim
--- keeps the first-person frame -- your head, carrying the camera's own rotation (the rotation and
--- not a lookAt, so a wall run's camera bank survives).
---
--- Returns nil in first person, and SpellshotInput then reads `camera.CFrame` exactly as it does
--- today. First-person aiming is untouched, to the byte.
---
--- The cost, stated rather than hidden: in third person the crosshair and the shot are no longer the
--- same ray, so a shot can land a little off the crosshair, most visibly at close range. That is the
--- price of not touching hit registration, and it is the right trade for a testing view.
VFXLibrary.LocalAimCFrame = function()
	if firstPerson then return nil end
	-- The camera's FOCUS is the point the view is built around, and the shoulder shift below moves it
	-- with the camera -- so aiming from the focus keeps the crosshair and the shot on one line instead
	-- of a couple of studs apart. It sits about TP_SHOULDER from the head, comfortably inside the
	-- distance the server will accept for a shot origin. The head is the fallback if the focus is
	-- somewhere unexpected (a spectator subject, a frame before the camera has solved).
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local focus = camera.Focus.Position
	if head and (focus - head.Position).Magnitude > 8 then focus = head.Position end
	return camera.CFrame.Rotation + focus
end

----------------------------------------------------------------------------------------------------
-- core GUI
----------------------------------------------------------------------------------------------------
-- Roblox's built-in health display is redundant with the pop-art HP bar and, worse, contradicts
-- it: the core bar reads raw Humanoid.Health while the HUD bar is the one carrying the status
-- treatments. Retried because the core GUI is not always ready on the first frame of a play
-- session, and a silent failure here looks exactly like "the setting did nothing".
local function disableCoreHealth()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end
disableCoreHealth()
task.defer(disableCoreHealth)
task.delay(1, disableCoreHealth)

pcall(function()
	StarterGui:SetCore("TopbarEnabled", true)
end)

----------------------------------------------------------------------------------------------------
-- hide the local character
----------------------------------------------------------------------------------------------------
-- ALL of it, not just the head: your camera draws the viewmodel instead. Roblox's own
-- TransparencyController already does most of this in first person, but it stops re-asserting the
-- moment it thinks you might be in third person, and accessory handles (a hat brim, a backpack)
-- sit one level deeper than the direct children and were the one thing still poking into frame.
-- LocalTransparencyModifier is client-only and does not replicate, so other players still see a
-- whole character.
local hiddenConns = {}
local hiddenParts = {}

--- Put the local body back on screen. The hide loop below stops re-asserting the moment
--- `firstPerson` goes false, but it has been writing 1 every frame until then, and Roblox's own
--- TransparencyController will not undo a value another script set -- so the parts are written back
--- to 0 once, here.
local function showLocalBody()
	for i = #hiddenParts, 1, -1 do
		local inst = hiddenParts[i]
		if not inst.Parent then
			table.remove(hiddenParts, i)
		else
			inst.LocalTransparencyModifier = 0
		end
	end
end

local function hideCharacter(character)
	for _, c in ipairs(hiddenConns) do c:Disconnect() end
	hiddenConns = {}
	if not FIRST_PERSON then return end

	hiddenParts = {}
	local hidden = hiddenParts
	local function track(inst)
		if inst:IsA("BasePart") or inst:IsA("Decal") or inst:IsA("Texture") then
			hidden[#hidden + 1] = inst
			-- (2026-10-29) not while the Wardrobe editor is open: its camera looks at this body (WardrobeEditor sets WardrobeOpen)
			inst.LocalTransparencyModifier = (firstPerson and not player:GetAttribute("WardrobeOpen")) and 1 or 0
		end
	end
	for _, d in ipairs(character:GetDescendants()) do track(d) end
	table.insert(hiddenConns, character.DescendantAdded:Connect(function(d) task.defer(track, d) end))
	table.insert(hiddenConns, RunService.RenderStepped:Connect(function()
		if not firstPerson or player:GetAttribute("WardrobeOpen") then return end   -- (2026-10-29) the Wardrobe shows the body
		for i = #hidden, 1, -1 do
			local inst = hidden[i]
			if not inst.Parent then
				table.remove(hidden, i)
			elseif inst.LocalTransparencyModifier < 1 then
				inst.LocalTransparencyModifier = 1
			end
		end
	end))
end

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
-- CastPose drives every character's third-person stance off the replicated MoveState attribute.
-- Started here as well as in AbilityFX so the body animation system is live even if no ability has
-- ever been cast. It has nothing to do with what this client renders for itself.
CastPose.Start()

local currentCharacter = nil

local function onCharacter(character)
	currentCharacter = character
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")
	-- UniformAvatar's ApplyDescription swaps the limbs a beat after spawn
	task.wait(0.35)
	if currentCharacter ~= character then return end

	hideCharacter(character)
	local built = Viewmodel.Build(character)
	if not built then
		warn("[FirstPersonController] viewmodel could not be built; first person is still active, "
			.. "casts just have no arm animation")
	end

	-- The local player's projectiles and beam leave the VIEWMODEL's fingertips, not the real
	-- character's hand -- those are two different places now, and the one you can see is the one
	-- the effect has to come from. Every other character keeps the ordinary body-welded origin.
	VFXLibrary.LocalCharacter = character
	applyMuzzleSources()

	-- the overhead nameplate health bar is a separate display from the core GUI one above, and it
	-- also pops in on damage
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.Died:Once(function()
			Viewmodel.Destroy()
		end)
	end
end

if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)
player.CharacterRemoving:Connect(function()
	currentCharacter = nil
	VFXLibrary.LocalBeamOrigin = nil
	VFXLibrary.LocalMuzzle = nil
	VFXLibrary.LocalCharacter = nil
	Viewmodel.Destroy()
end)

-- a loadout change recolours the sleeves without rebuilding the rig
player:GetAttributeChangedSignal("Element"):Connect(function()
	Viewmodel.Refresh()
end)

-- Rebuild if the rig goes away underneath us (a respawn landing a Destroy after a Build).
-- Rate-limited so a genuinely un-buildable character retries occasionally rather than every frame.
local nextBuild = 0
-- Bound AFTER the camera, and after MovementController's slide roll at Camera+1. The arms are solved
-- from camera.CFrame, and a plain RenderStepped runs before the camera moves, so every arm sat one
-- frame behind the view: a stud low on the way up a jump, a stud high on the way down, a frame
-- late on every turn.
--- FACING. LockFirstPerson turns the body with the camera for free. The Classic camera does not: it
--- leaves Humanoid.AutoRotate to swing the body toward whatever direction you are WALKING, so
--- holding S spins you round to face away and then walks you off backwards. That is a movement
--- camera's behaviour, not a shooter's -- the body has to keep pointing where you are AIMING
--- whatever the keys say, or strafing reads as a pirouette and every ability leaves the wrong side.
---
--- So AutoRotate goes off and the root takes the camera's yaw directly, flattened: pitch belongs to
--- the camera, not to the spine. Written from this render step, which runs after the camera has
--- solved; nothing else in the game touches AutoRotate, and no motor writes the root's CFrame (they
--- all drive velocity), so there is nothing here to fight.
local FLATTEN = Vector3.new(1, 0, 1)
local function faceCamera(camCF)
	local character = currentCharacter
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then return end
	if hum.AutoRotate then hum.AutoRotate = false end
	local look = camCF.LookVector * FLATTEN
	if look.Magnitude < 1e-3 then return end          -- straight up or straight down: keep the facing
	root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
end

RunService:BindToRenderStep("SpellshotViewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt)
	-- THE SHOULDER. Roblox's Classic camera sits dead behind the character, which puts your own body
	-- across the middle of the screen and over whoever you are aiming at. The reference framing keeps
	-- the body in a corner and the centre clear, so the whole camera is shifted sideways and a little
	-- up AFTER the CameraModule has placed it.
	--
	-- A TRANSLATION, never a rotation. The look direction is untouched, so nothing downstream that
	-- reads camera.CFrame.LookVector changes, and there is no feedback loop with the CameraModule to
	-- shake against. The focus moves with it, because the focus is what the aim frame is taken from.
	if not firstPerson then
		local cf = camera.CFrame
		local shift = cf.RightVector * TP_SHOULDER.X + cf.UpVector * TP_SHOULDER.Y
		camera.CFrame = cf + shift
		camera.Focus = camera.Focus + shift
		faceCamera(cf)
	end
	if currentCharacter and currentCharacter.Parent and not Viewmodel.IsBuilt() then
		-- ...and only onto a body that is still alive (2026-09-21): a dead character stays parented to
		-- workspace until the respawn, so this rebuilt the rig the Died hook had just torn down and the
		-- arms hung in the death camera for the whole wait.
		local hum = currentCharacter:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local now = os.clock()
			if now >= nextBuild then
				nextBuild = now + 0.5
				Viewmodel.Build(currentCharacter)
			end
		end
	end
	Viewmodel.Update(dt)
end)

-- CURSOR. First person has no pointer: the crosshair is the aim. Holding Left Alt brings the cursor
-- out (and stops the mouse turning the camera) for as long as it is held. This has to be a render
-- step above Camera priority, because the CameraModule re-locks the mouse in its own step every
-- frame. DevPanel's cursor step runs one slot later (Camera + 10), so it wins while the panel is
-- open. Roblox's own menu keeps its cursor.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
RunService:BindToRenderStep("SpellshotCursor", Enum.RenderPriority.Camera.Value + 9, function()
	if GuiService.MenuIsOpen then
		UserInputService.MouseIconEnabled = true
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseIconEnabled = false
		-- LockFirstPerson locks the mouse to the centre for us; the Classic camera does not, and that
		-- is not cosmetic: SpellshotInput drops every M1 press unless MouseBehavior is LockCenter. Same
		-- reason this step sits above Camera priority as the cursor does -- the CameraModule sets
		-- MouseBehavior in its own step, every frame.
		if not firstPerson then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- the V toggle
----------------------------------------------------------------------------------------------------
--- Swap the view. Three things move and nothing else does: the Roblox camera mode, whether the local
--- body is drawn, and where the local player's own effects leave from.
---
--- WHAT IS DELIBERATELY NOT HERE: Viewmodel.Destroy(). Viewmodel.Play sets its current clip with no
--- built check, and only Viewmodel.Update clears it -- and Update returns early when the rig is gone.
--- So a single cast with the arms destroyed would leave Viewmodel.IsPlaying() true for the rest of
--- the round, and SpellshotInput gates every M1 on exactly that. The rig therefore stays built and
--- stays animating in both views; Viewmodel simply stops drawing it, and moves its muzzle to the
--- body's hand, both off this same CameraMode.
local function setFirstPerson(on)
	if firstPerson == on then return end
	firstPerson = on
	applyCameraMode()
	applyMuzzleSources()
	-- Going back to first person needs nothing done to hide the body: the hide loop re-asserts on its
	-- own as soon as the flag is true again. Coming out is the direction that needs a hand -- and
	-- going back in has to hand AutoRotate back, because LockFirstPerson owns the facing there.
	if firstPerson then
		local c = currentCharacter
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum then hum.AutoRotate = true end
	else
		showLocalBody()
	end
end

-- (2026-10-19, audit P5F-02) the toggle was dev accounts only until the owner decided: a shoulder camera sees round
-- corners and over cover. 2026-10-27, the owner decided: "make a small button to go third person so mobile players can
-- do too, put it in settings". Every player has it now, as the Third Person setting (VIDEO tab, saved with the rest),
-- and V flips that same setting, so the menu, the key and the saved value never disagree.
if FIRST_PERSON and ALLOW_THIRD_PERSON_TOGGLE then
	local okS, Settings = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	end)
	if okS and type(Settings) == "table" and Settings.ById and Settings.ById.ThirdPerson then
		Settings.Bind("ThirdPerson", function(v) setFirstPerson(v ~= true) end)
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode ~= TP_KEY then return end
			Settings.Set("ThirdPerson", firstPerson)   -- in first person now: third person on, and back
		end)
	end
end
