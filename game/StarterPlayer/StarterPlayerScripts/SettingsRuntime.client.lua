--[[
	SettingsRuntime  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/SettingsRuntime

	STAGE 2 OF BUILD PROMPT #15. The appliers that do not belong to any other script: the view, the
	mixer, the mouse, and the quality tier. Anything a specific script already owns is applied there
	instead -- PopArtHUD does the HUD, Viewmodel does camera shake, StatusReactions does status
	intensity, SpellshotInput and MovementController do the keybinds.

	Everything here is Settings.Bind(id, fn): the function runs once at startup with whatever the
	value is, and again on every change, so there is no separate "apply all on load" pass to forget.

	WHAT EACH ROW ACTUALLY TOUCHES

	  Field of View      camera.FieldOfView. The viewmodel arms are fitted at 90, so they read a
	                     little larger below it and smaller above -- the same trade every shooter
	                     makes, and the row says so.
	  Brightness         a ColorCorrectionEffect on Lighting, made here and client-only. Not
	                     Lighting.Brightness, which is the sun's strength and would relight the map
	                     rather than adjust the picture.
	  Graphics Quality   shadows on or off, and an effect-density multiplier the VFX library applies
	                     to every emitter it builds.
	  Motion Blur        a BlurEffect driven by how fast the camera is turning, scaled by the row's
	                     strength. 0 is off in the real sense: the effect is destroyed, not left
	                     sitting at zero size.
	  Sensitivity        a multiplier on the camera's mouse turn, applied one step after Roblox's camera, riding on top of whatever the
	                     player chose in Roblox's own settings. The slider is a position and its Curve is the multiplier
	                     (Settings.Multiplier): 0.125x at 0, exactly 1.0x at 50, 5x at 100, exponential either side, so
	                     every notch is the same ratio. (Build Prompt #25: the linear 0.2-1-3 mapping before it spent
	                     most of the slider on changes too small to feel.)
	  While Channeling   a percentage OF that, applied while the character's Channeling attribute is set
	                     (SpellshotInput sets it around an Ultimate channel). 60% by default, on a log track.
	  Invert Y-Axis      the pitch of the camera's turn, negated in that same step.
	  Volumes            three SoundGroups -- SFX, Music, Interface -- with Master multiplied into
	                     each. Every Sound that appears without a group of its own is assigned one,
	                     so sounds the VFX library creates later are covered too.
	  Mute When Unfocused  drops every group while the window is in the background.
	  Colorblind-Safe    repaints every player's uniform, per viewer, from the safe palette.

	TWO THINGS ROBLOX WILL NOT LET A GAME SCRIPT DO, AND WHAT IS DONE INSTEAD

	  1. UserGameSettings.SavedQualityLevel is RobloxScript-only ("Insufficient permissions to set
	     SavedQualityLevel"). Graphics Quality therefore drives what WE draw -- shadows and effect
	     density -- and leaves Roblox's own render quality to the player's Roblox settings, where
	     they set it once for every game they play.
	  2. UserGameSettings.CameraYInverted is RobloxScript-only as well, and Roblox's camera never reads
	     UserInputService.MouseDeltaSensitivity, so Sensitivity and Invert Y are both done by hand, one
	     render step after Roblox's camera: the turn it added this frame is scaled and (for Invert Y) its
	     pitch negated, then laid onto what the camera showed the frame before. Roblox's camera rebuilds
	     every frame from wherever the view points (measured 2026-09-15: a CFrame set by hand stays put),
	     so what this step leaves is the camera's next starting point and nothing can drift. Negating the
	     view itself, the first Invert Y, was undone by that rebuild. Yaw, pitch and roll go through
	     ToOrientation / fromOrientation, so the slide's camera roll is carried through untouched.

	PERSISTENCE lives here rather than in the module, for the reason the module's header gives: a
	tool thread gets its own copy of the module, and a copy that owned the remote could push its own
	defaults over the real save. If the remote never appears the game still runs on defaults and
	nothing is saved, which is the right failure -- a settings menu must never be dead because a
	DataStore is.

	SOUND GROUPS ARE MADE ON THE CLIENT. They are local instances: they mix what THIS player hears
	and never touch anyone else. A Sound that already belongs to some other group is left alone.
	(SoundGroups do not nest -- SoundGroup.SoundGroup is not a property -- so Master is a multiplier
	into each bus rather than a group they all feed.)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Settings = require(spellFolder:WaitForChild("SpellshotSettings"))
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))

----------------------------------------------------------------------------------------------------
-- persistence
----------------------------------------------------------------------------------------------------
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Spellshot", 30)
	-- (2026-10-19, audit P5B-20) `folder and A or folder:WaitForChild(...)` indexed a nil folder when it never came
	local remote = folder and (folder:FindFirstChild("SettingsSync") or folder:WaitForChild("SettingsSync", 30))
	if not remote then
		warn("[SettingsRuntime] SettingsSync missing; settings will not be saved this session")
		return
	end
	remote.OnClientEvent:Connect(function(tbl)
		-- what just arrived IS the save; do not send it straight back -- unless Load kept changes the player made
		-- before it arrived (2026-10-19, audit P2-09): then the merged whole is due, and goes out on the debounce
		if not Settings.Load(tbl) then
			Settings.MarkSaved()
		end
	end)
	remote:FireServer("request")
	RunService.Heartbeat:Connect(function()
		local snapshot = Settings.TakePush()
		if snapshot then remote:FireServer("save", snapshot) end
	end)
end)

----------------------------------------------------------------------------------------------------
-- view
----------------------------------------------------------------------------------------------------
Settings.Bind("FieldOfView", function(v)
	camera.FieldOfView = v
end)
-- the camera instance is replaced on some respawns; put the choice back on the new one
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera or camera
	camera.FieldOfView = Settings.Get("FieldOfView")
end)

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "SpellshotBrightness"
grade.Enabled = true
grade.Parent = Lighting

-- 50 is neutral. Build Prompt #25, measured on the Hub (mean L* at each quarter of the slider): the dark half steps an even
-- ~13 L* with nothing crushed, but the palette is already light, so +0.15 clipped 36% of the picture to pure white and
-- +0.30 clipped 53% and flattened its contrast. The bright half therefore tops out at +0.10.
local BRIGHT_DOWN, BRIGHT_UP = 0.30, 0.10
-- (2026-10-19, audit P5C-11) while an Eclipse's grade is on (UmbraFX sets the client-local Lighting.UmbraGrade) the
-- slider may darken but not brighten, so a high Brightness cannot cancel the darkness an enemy's Eclipse paints;
-- the slider's own value is kept and re-applied when the grade lifts.
local function applyBrightness()
	local v = Settings.Get("Brightness")
	local b, c
	if v <= 50 then
		b = (v - 50) / 50 * BRIGHT_DOWN
		c = (50 - v) / 50 * 0.06
	else
		b = (v - 50) / 50 * BRIGHT_UP
		c = 0
	end
	if Lighting:GetAttribute("UmbraGrade") then b = math.min(b, 0) end
	grade.Brightness, grade.Contrast = b, c
end
Settings.Bind("Brightness", applyBrightness)
Lighting:GetAttributeChangedSignal("UmbraGrade"):Connect(applyBrightness)

----------------------------------------------------------------------------------------------------
-- quality
----------------------------------------------------------------------------------------------------
-- Effect density is read by VFXLibrary when it builds an emitter. A plain field on the module
-- rather than a signal, because an emitter reads it at the moment it is made.
local QUALITY = {
	{ shadows = false, density = 0.45 },
	{ shadows = false, density = 0.75 },
	{ shadows = true, density = 1.00 },
	{ shadows = true, density = 1.15 },
}

Settings.Bind("GraphicsQuality", function(v)
	local q = QUALITY[v] or QUALITY[3]
	Settings.QualityShadows = q.shadows
	Settings.ApplyShadows()           -- (2026-10-19, audit P5F-13) AND the zone's light profile (HubClient)
	Settings.EffectDensity = q.density
end)

Settings.Bind("ReduceEnemyVFX", function(v)
	Settings.ThinEnemyVFX = v and true or false
end)

----------------------------------------------------------------------------------------------------
-- motion blur
----------------------------------------------------------------------------------------------------
local blur, blurConn, lastLook
local blurStrength = 0

-- The blur only ever answers to how fast the view is SWEEPING: below about 40 deg/s there is none
-- at all, so walking and small aim corrections stay sharp and only a real flick smears. MAX_BLUR is
-- what 100% gives at a fast flick; the strength row scales it.
-- Build Prompt #25: the strength scales the blur between MIN_BLUR and MAX_BLUR rather than up from zero. Measured on the
-- Hub, a BlurEffect of Size 1 removes no visible detail and Size 2 only 13%, so a plain 0..18 scale spent the bottom ~15%
-- of the row doing nothing; from 3 up the loss grows about evenly with size.
local BLUR_FLOOR, BLUR_RANGE, MIN_BLUR, MAX_BLUR = 40, 260, 3, 18

Settings.Bind("MotionBlur", function(v)
	blurStrength = v / 100
	if blurStrength <= 0 then
		if blurConn then blurConn:Disconnect() blurConn = nil end
		if blur then blur:Destroy() blur = nil end
		lastLook = nil
		return
	end
	if blur then return end          -- already running; the new strength is picked up per frame
	blur = Instance.new("BlurEffect")
	blur.Name = "SpellshotMotionBlur"
	blur.Size = 0
	blur.Parent = Lighting
	blurConn = RunService.RenderStepped:Connect(function(dt)
		local look = camera.CFrame.LookVector
		if lastLook then
			-- how far the view swept this frame, in degrees per second
			local rate = math.deg(math.acos(math.clamp(look:Dot(lastLook), -1, 1))) / math.max(dt, 1 / 240)
			local want = math.clamp((rate - BLUR_FLOOR) / BLUR_RANGE, 0, 1) * (MIN_BLUR + (MAX_BLUR - MIN_BLUR) * blurStrength)
			blur.Size = blur.Size + (want - blur.Size) * math.clamp(14 * dt, 0, 1)
		end
		lastLook = look
	end)
end)

----------------------------------------------------------------------------------------------------
-- mouse
----------------------------------------------------------------------------------------------------
-- The slider's multiplier is Settings.Multiplier("Sensitivity"), from its Curve in SpellshotSettings.

-- THE LOOK STEP. UserInputService.MouseDeltaSensitivity was the first answer and it did nothing (the user, 2026-09-15:
-- "sens is always high"): Roblox's camera turns from the raw mouse delta and never reads it. So the slider is
-- applied to the turn itself, one step after the camera: what the camera shows now, minus what it showed last
-- frame, is the turn it just added. A view changed by anything else between frames (a move's reveal turning you to
-- face the spot) is taken as the new starting point, not scaled as if you had turned. Touch and gamepad turns pass
-- through unscaled: this slider is the mouse's.
local PITCH_LIMIT = math.rad(79.5)         -- inside the camera's own 80 degree clamp, so the two never fight
local lookGain, invertY = 1, false
local shown, shownCam                      -- the { pitch, yaw } this step left the camera at, and on which camera
UserInputService.MouseDeltaSensitivity = 1   -- (never read by the camera; kept neutral)

local function wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function mouseTurn()
	local t = UserInputService:GetLastInputType()
	return t ~= Enum.UserInputType.Touch and not t.Name:find("^Gamepad")
end

local function applySensitivity()
	local base = Settings.Multiplier("Sensitivity")
	local character = player.Character
	if character and character:GetAttribute("Channeling") then
		base *= Settings.Get("ChannelSensitivity") / 100
	end
	lookGain = math.clamp(base, 0.05, 10)
end

Settings.Bind("Sensitivity", applySensitivity)
Settings.Bind("ChannelSensitivity", applySensitivity)

-- TOUCH SENSITIVITY (2026-10-04): a swipe's turn goes through the same look step, scaled by its own slider. 1.00x in
-- the middle leaves Roblox's own touch turn untouched.
local touchGain = 1
Settings.Bind("TouchSensitivity", function()
	touchGain = math.clamp(Settings.Multiplier("TouchSensitivity"), 0.05, 10)
end)

local channelConn
local function watchChannel(character)
	if channelConn then channelConn:Disconnect() end
	channelConn = character:GetAttributeChangedSignal("Channeling"):Connect(applySensitivity)
	applySensitivity()
end
if player.Character then watchChannel(player.Character) end
player.CharacterAdded:Connect(watchChannel)

-- before the camera: a view that no longer points where this step left it was turned by something else; start there
RunService:BindToRenderStep("SpellshotLookBase", Enum.RenderPriority.Camera.Value - 1, function()
	if not shown or shownCam ~= camera then return end
	local rx, ry = camera.CFrame:ToOrientation()
	if math.abs(rx - shown[1]) > 1e-4 or math.abs(wrapAngle(ry - shown[2])) > 1e-4 then
		shown = { rx, ry }
	end
end)

-- after the camera (the slide roll's slot, and the roll is carried through): scale the turn it just added
RunService:BindToRenderStep("SpellshotLook", Enum.RenderPriority.Camera.Value + 1, function()
	local cf = camera.CFrame
	local rx, ry, rz = cf:ToOrientation()
	if not shown or shownCam ~= camera then
		shown, shownCam = { rx, ry }, camera
		return
	end
	local gain = 1
	if mouseTurn() then
		gain = lookGain
	elseif UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		gain = touchGain
	end
	if gain == 1 and not invertY then
		shown = { rx, ry }
		return
	end
	local dPitch, dYaw = rx - shown[1], wrapAngle(ry - shown[2])
	if invertY then dPitch = -dPitch end
	local pitch = math.clamp(shown[1] + dPitch * gain, -PITCH_LIMIT, PITCH_LIMIT)
	local yaw = shown[2] + dYaw * gain
	if player.CameraMode == Enum.CameraMode.LockFirstPerson then
		camera.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(pitch, yaw, rz)
	else
		-- THIRD PERSON ORBITS A SUBJECT. Spinning the camera on the spot here points it off the
		-- character; the CameraModule puts it back next frame; this step turns it off again -- and the
		-- two fight every frame, which reads as the whole view vibrating. Swing the camera AROUND the
		-- focus instead, keeping the distance it already has, and there is nothing to fight over.
		local focus = camera.Focus.Position
		local dist = (cf.Position - focus).Magnitude
		camera.CFrame = CFrame.new(focus) * CFrame.fromOrientation(pitch, yaw, rz) * CFrame.new(0, 0, dist)
	end
	shown = { pitch, yaw }
end)

-- INVERT Y is the look step's: it negates the pitch of the turn, not of the view.
Settings.Bind("InvertY", function(on)
	invertY = on and true or false
end)

----------------------------------------------------------------------------------------------------
-- colourblind-safe Elements
----------------------------------------------------------------------------------------------------
-- The uniform is where an Element is actually read in a fight: torso for identity at range, a
-- darker sleeve, a lighter hand. UniformAvatar paints those on the SERVER, the same for everyone,
-- so a per-viewer palette has to be repainted here on the client -- which is right anyway, because
-- one player needing the safe palette should not change what anyone else sees.
--
-- The safe palette gives a base colour per Element; the sleeve and hand are derived from it by the
-- same step down and step up the original tones use, so the three-tone read survives the swap.
local TORSO_PARTS = { "UpperTorso", "LowerTorso", "Torso" }
local SLEEVE_PARTS = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local HAND_PARTS = { "LeftHand", "RightHand" }

local function tonesFor(element)
	local def = Config.Elements[element]
	if not def then return nil end
	-- (2026-10-19, audit P5C-01) an Element the safe palette has no entry for (Aqua) keeps its own three: ElementColor's
	-- gold fallback is no colour of its, and painting it would restyle a whole Element nobody asked to move
	if not Settings.ElementColors[element] then return def.Base, def.Dark, def.Light end
	local base = Settings.Get("ColorblindSafe") and Settings.ElementColor(element) or def.Base
	-- Only the Elements the safe palette actually moves get derived tones. The rest keep the three
	-- the artist chose, so turning the setting on does not quietly restyle six Elements to fix two.
	if base == def.Base then return def.Base, def.Dark, def.Light end
	return base, base:Lerp(Color3.new(0, 0, 0), 0.35), base:Lerp(Color3.new(1, 1, 1), 0.35)
end

local function paint(character, element)
	local torso, sleeve, hand = tonesFor(element)
	if not torso then return end
	for _, list in ipairs({ { TORSO_PARTS, torso }, { SLEEVE_PARTS, sleeve } }) do   -- (2026-10-27) hands are skin now (UniformAvatar), not repainted
		for _, name in ipairs(list[1]) do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then part.Color = list[2] end
		end
	end
end

-- (2026-10-19, audit P5C-01) UMBRA'S DECOY DOUBLE is a server-side copy of the body (workspace.UmbraDecoys, stamped
-- DecoyOwner = the owner's UserId), so it arrives in the server's colours. Left alone, the safe palette paints the real
-- Umbra and not the copy, and the setting becomes a decoy detector. The copy is painted as its owner is, on arrival
-- (before DecoyPeel reads its colours) and again a beat later in case a part lands late.
local decoyFolder = nil
local function paintDecoy(decoy)
	if not decoy:IsA("Model") then return end
	local owner = Players:GetPlayerByUserId(decoy:GetAttribute("DecoyOwner") or 0)
	if owner then paint(decoy, owner:GetAttribute("Element") or Config.DefaultLoadout.Element) end
end

local function repaintAll()
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if character then
			paint(character, p:GetAttribute("Element") or Config.DefaultLoadout.Element)
		end
	end
	if decoyFolder then
		for _, decoy in ipairs(decoyFolder:GetChildren()) do paintDecoy(decoy) end
	end
end

local function watchDecoys(folder)
	if decoyFolder or not folder:IsA("Folder") then return end
	decoyFolder = folder
	for _, decoy in ipairs(folder:GetChildren()) do paintDecoy(decoy) end
	folder.ChildAdded:Connect(function(decoy)
		paintDecoy(decoy)
		task.delay(0.6, function()
			if decoy.Parent == folder then paintDecoy(decoy) end
		end)
	end)
end
if workspace:FindFirstChild("UmbraDecoys") then watchDecoys(workspace.UmbraDecoys) end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "UmbraDecoys" then watchDecoys(c) end
end)

local function watchPlayer(p)
	local function onCharacter(character)
		-- UniformAvatar's ApplyDescription lands a beat after the character does
		task.delay(0.6, function()
			if p.Character == character then
				paint(character, p:GetAttribute("Element") or Config.DefaultLoadout.Element)
			end
		end)
		-- (2026-10-19, audit P5F-11) and again each time the server says its uniform write has landed (UniformStamp,
		-- set after the colours): a slow ApplyDescription or an Element change without a respawn no longer leaves the
		-- server's colours on top of this viewer's paint
		character:GetAttributeChangedSignal("UniformStamp"):Connect(function()
			if p.Character == character then
				paint(character, p:GetAttribute("Element") or Config.DefaultLoadout.Element)
			end
		end)
	end
	if p.Character then onCharacter(p.Character) end
	p.CharacterAdded:Connect(onCharacter)
	p:GetAttributeChangedSignal("Element"):Connect(function()
		if p.Character then
			paint(p.Character, p:GetAttribute("Element") or Config.DefaultLoadout.Element)
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
Settings.Bind("ColorblindSafe", repaintAll)

----------------------------------------------------------------------------------------------------
-- audio
----------------------------------------------------------------------------------------------------
local function makeGroup(name)
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then return existing end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	return g
end

local groups = {
	SFX = makeGroup("SpellshotSFX"),
	Music = makeGroup("SpellshotMusic"),
	Interface = makeGroup("SpellshotInterface"),
}

--- Which bus a sound belongs on. Nothing in the project is tagged, so this reads the two things
--- that are actually true of a sound: where it lives, and what it is called.
local function busFor(sound)
	local name = sound.Name:lower()
	if name:find("music") or name:find("theme") then return groups.Music end
	local p = sound.Parent
	while p do
		if p:IsA("ScreenGui") or p:IsA("PlayerGui") then return groups.Interface end
		if p == workspace or p == ReplicatedStorage or p == SoundService then break end
		p = p.Parent
	end
	return groups.SFX
end

local function claim(inst)
	if inst:IsA("Sound") and inst.SoundGroup == nil then
		inst.SoundGroup = busFor(inst)
	end
end

for _, root in ipairs({ workspace, ReplicatedStorage, SoundService, player:WaitForChild("PlayerGui") }) do
	for _, d in ipairs(root:GetDescendants()) do claim(d) end
	root.DescendantAdded:Connect(function(d)
		-- deferred: a Sound is usually parented before its name and properties are set
		task.defer(claim, d)
	end)
end

local muted = false

-- Loudness, not amplitude (Settings.Gain): a SoundGroup's Volume is linear gain, and a linear 0..100 put the whole top half
-- of each slider inside 6 dB (Build Prompt #25).
local function applyVolumes()
	local master = muted and 0 or Settings.Gain("VolMaster")
	groups.SFX.Volume = master * Settings.Gain("VolSFX")
	groups.Music.Volume = master * Settings.Gain("VolMusic")
	groups.Interface.Volume = master * Settings.Gain("VolInterface")
end

for _, id in ipairs({ "VolMaster", "VolSFX", "VolMusic", "VolInterface" }) do
	Settings.Bind(id, applyVolumes)
end

UserInputService.WindowFocusReleased:Connect(function()
	if Settings.Get("MuteUnfocused") then
		muted = true
		applyVolumes()
	end
end)
UserInputService.WindowFocused:Connect(function()
	muted = false
	applyVolumes()
end)
Settings.Bind("MuteUnfocused", function(v)
	if not v and muted then
		muted = false
		applyVolumes()
	end
end)
