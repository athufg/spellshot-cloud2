--[[
	SpellshotSettings  (ModuleScript)  ->  ReplicatedStorage/Spellshot/SpellshotSettings

	STAGE 2 OF BUILD PROMPT #15. One table of what a setting IS, one store of what it is set to, and
	one way to hear about a change. Every other script reads this module; none of them keeps its own
	copy of a preference.

	  Settings.Get(id)              the current value
	  Settings.Set(id, value)       set it (validated, saved, listeners fire)
	  Settings.Bind(id, fn)         call fn(value) now AND on every later change -> returns a handle
	  Settings.OnAnyChange(fn)      fn(id, value) for every change
	  Settings.Snapshot()           a plain {id = value} copy

	WHO OWNS WHAT. The module owns definitions, values and persistence. It applies NOTHING. The
	script that owns a piece of the game binds to the ids it cares about:

	  SettingsRuntime   view, audio, mouse, quality, flashing, text size
	  PopArtHUD         UI size, HUD opacity, crosshair, kill feed
	  Viewmodel         camera shake
	  StatusReactions   status intensity, reduce flashing
	  SpellshotInput    the ability keybinds, M1 auto-fire
	  MovementController crouch / slide keybinds
	  PopupScaler       damage numbers

	PERSISTENCE. The client is the source of truth while you play; the server is the one that can
	write a DataStore. The client pushes a whole snapshot on a debounce and SettingsStore validates
	it again server-side before saving -- a client can only ever spoil its own settings, and only
	within the range each definition allows.

	THE MODULE DOES NOT TALK TO THE REMOTE. SettingsRuntime does, calling Load() with what arrives
	and TakePush() when a save is due. Every LocalScript shares one require cache, so they all share
	this one store -- but a tool running code in its own thread gets a SEPARATE copy of the module,
	and if the remote lived here that copy would happily push its own defaults over the real save.

	DEFAULTS AND VERSIONING. A value that fails validation falls back to the definition's default,
	and an id that no longer exists is dropped on load, so removing or re-ranging a setting later
	cannot leave a player stuck with a value the game no longer understands.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = {}

Settings.Version = 1
Settings.PushDebounce = 0.75          -- seconds of quiet before the client sends a snapshot

-- Set by SettingsRuntime from the quality tier and the Reduce Enemy VFX row, read by VFXLibrary as
-- it builds an emitter. Plain fields, not signals: an emitter reads them at the moment it is made.
Settings.EffectDensity = 1
Settings.ThinEnemyVFX = false

----------------------------------------------------------------------------------------------------
-- definitions
----------------------------------------------------------------------------------------------------
-- Kind is what the value IS, not how it is drawn: "number" (Min/Max/Step), "bool", "option" (an
-- index into Options) and "key" (a KeyCode name). Plat marks a row that only exists on one kind of
-- device; the menu never shows the other list, and the store keeps whatever it was given.
local D = {
	-- VIDEO
	{ Id = "GraphicsQuality", Kind = "option", Default = 3, Options = { "LOW", "MEDIUM", "HIGH", "ULTRA" } },
	{ Id = "FieldOfView", Kind = "number", Default = 90, Min = 70, Max = 110 },
	{ Id = "Brightness", Kind = "number", Default = 50, Min = 0, Max = 100 },
	{ Id = "CameraShake", Kind = "number", Default = 100, Min = 0, Max = 100 },
	-- Strength, not a switch: 0 is off, and the effect is destroyed rather than left at zero.
	{ Id = "MotionBlur", Kind = "number", Default = 0, Min = 0, Max = 100 },
	{ Id = "ReduceEnemyVFX", Kind = "bool", Default = false },

	-- CONTROLS (keyboard / gamepad)
	-- Build Prompt #25: the slider is a POSITION (0..100) and Curve turns it into the multiplier, exponential either side of
	-- 50, so every notch is the same RATIO (turn speed is felt multiplicatively): 0 = 0.125x, 50 = 1.0x, 100 = 5x.
	{ Id = "Sensitivity", Kind = "number", Default = 50, Min = 0, Max = 100, Plat = "PC", Curve = { Low = 0.125, High = 5 } },
	-- A percentage OF the base sensitivity, on a log track: 20% -> 60% is as much slider as 60% -> 200%.
	{ Id = "ChannelSensitivity", Kind = "number", Default = 60, Min = 20, Max = 200, Plat = "PC", Track = "log" },
	{ Id = "InvertY", Kind = "bool", Default = false, Plat = "PC" },
	{ Id = "ToggleCrouch", Kind = "bool", Default = false, Plat = "PC" },
	{ Id = "Bind_Primary", Kind = "key", Default = "F", Plat = "PC" },
	{ Id = "Bind_Mobility", Kind = "key", Default = "Q", Plat = "PC" },
	{ Id = "Bind_Defense", Kind = "key", Default = "E", Plat = "PC" },
	{ Id = "Bind_Ultimate", Kind = "key", Default = "R", Plat = "PC" },
	{ Id = "Bind_Crouch", Kind = "key", Default = "LeftControl", Plat = "PC" },
	-- Interact is the Hub's prompts (HubClient applies it). G, because E is the Defense ability.
	{ Id = "Bind_Interact", Kind = "key", Default = "G", Plat = "PC" },
	-- The PAD column. A gamepad button arrives through InputBegan with a KeyCode like any other
	-- key, so a pad bind is the same kind of value and the same code path as a keyboard one.
	{ Id = "Pad_Primary", Kind = "key", Default = "ButtonX", Plat = "PC" },
	{ Id = "Pad_Mobility", Kind = "key", Default = "ButtonL1", Plat = "PC" },
	{ Id = "Pad_Defense", Kind = "key", Default = "ButtonR1", Plat = "PC" },
	{ Id = "Pad_Ultimate", Kind = "key", Default = "ButtonY", Plat = "PC" },
	{ Id = "Pad_Crouch", Kind = "key", Default = "ButtonL3", Plat = "PC" },
	{ Id = "Pad_Interact", Kind = "key", Default = "ButtonB", Plat = "PC" },   -- ButtonX is Primary

	-- CONTROLS (touch)
	{ Id = "TouchSensitivity", Kind = "number", Default = 50, Min = 0, Max = 100, Plat = "Mobile", Curve = { Low = 0.125, High = 5 } },
	{ Id = "CameraAssist", Kind = "bool", Default = true, Plat = "Mobile" },
	{ Id = "AutoFire", Kind = "bool", Default = false, Plat = "Mobile" },
	{ Id = "ButtonSize", Kind = "number", Default = 100, Min = 50, Max = 150, Plat = "Mobile", Track = "log" },
	-- 65, not 100 (2026-10-04): seven opaque plates hid the lower right of the fight. It is the plate that fades; the icon stays solid.
	{ Id = "ButtonOpacity", Kind = "number", Default = 65, Min = 20, Max = 100, Plat = "Mobile" },
	{ Id = "LeftHanded", Kind = "bool", Default = false, Plat = "Mobile" },

	-- AUDIO. Loudness = true: the slider is how LOUD (Settings.Gain), not the raw gain. Music's default moved 60 -> 74 so it
	-- still plays at the gain it had (0.60).
	{ Id = "VolMaster", Kind = "number", Default = 100, Min = 0, Max = 100, Loudness = true },
	{ Id = "VolSFX", Kind = "number", Default = 100, Min = 0, Max = 100, Loudness = true },
	{ Id = "VolMusic", Kind = "number", Default = 74, Min = 0, Max = 100, Loudness = true },
	{ Id = "VolInterface", Kind = "number", Default = 100, Min = 0, Max = 100, Loudness = true },
	{ Id = "MuteUnfocused", Kind = "bool", Default = false, Plat = "PC" },

	-- HUD
	{ Id = "CrosshairColor", Kind = "option", Default = 1, Options = { "WHITE", "GOLD", "CYAN", "GREEN", "RED", "PINK" } },
	{ Id = "CrosshairShape", Kind = "option", Default = 1, Options = { "CROSS + DOT", "CROSS", "DOT", "CIRCLE" } },
	{ Id = "CrosshairSize", Kind = "number", Default = 100, Min = 50, Max = 200, Track = "log" },
	{ Id = "CrosshairOutline", Kind = "number", Default = 1, Min = 0, Max = 3 },
	{ Id = "DamageNumbers", Kind = "bool", Default = true },
	{ Id = "Compass", Kind = "bool", Default = true },
	{ Id = "StatusIntensity", Kind = "number", Default = 100, Min = 0, Max = 100 },
	{ Id = "UIScale", Kind = "number", Default = 100, Min = 50, Max = 150, Track = "log" },
	{ Id = "HUDOpacity", Kind = "number", Default = 100, Min = 20, Max = 100 },
	{ Id = "KillFeedDuration", Kind = "number", Default = 5, Min = 2, Max = 10 },

	-- ACCESS
	{ Id = "ColorblindSafe", Kind = "bool", Default = false },
	{ Id = "ReduceFlashing", Kind = "bool", Default = false },
	{ Id = "TextSize", Kind = "number", Default = 100, Min = 80, Max = 150, Track = "log" },
}

Settings.Defs = D
Settings.ById = {}
for _, def in ipairs(D) do
	Settings.ById[def.Id] = def
end

-- The crosshair swatch, in the order CrosshairColor indexes them.
Settings.CrosshairColors = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(245, 184, 0),
	Color3.fromRGB(18, 198, 231),
	Color3.fromRGB(126, 204, 36),
	Color3.fromRGB(228, 37, 31),
	Color3.fromRGB(236, 72, 153),
}

-- The colourblind-safe Element palette. Only the pairs that actually collide are moved: Pyro/Terra
-- (both warm, and Terra reads as Pyro to a protan) and Toxin/Cryo (both bright and desaturated to a
-- tritan). The rest keep their identity colour, because changing a colour nobody confuses only makes
-- the game harder to talk about.
Settings.ElementColors = {
	-- Pyro's pair is its identity colour twice over, and it has to BE SpellshotConfig's Pyro Base to
	-- the bit: SettingsRuntime.tonesFor decides "this one was not moved" by comparing the two. it
	-- carried a stale (233, 78, 27) (2026-09-21), so the compare failed and turning the toggle on
	-- repainted every Pyro player -- hue, sleeve and hand -- for an Element that never moves.
	Pyro = { Color3.fromRGB(242, 92, 13), Color3.fromRGB(242, 92, 13) },
	Cryo = { Color3.fromRGB(64, 181, 240), Color3.fromRGB(64, 181, 240) },
	Voltaic = { Color3.fromRGB(245, 199, 15), Color3.fromRGB(245, 199, 15) },
	Terra = { Color3.fromRGB(130, 107, 36), Color3.fromRGB(120, 78, 158) },
	Zephyr = { Color3.fromRGB(79, 209, 197), Color3.fromRGB(255, 255, 255) },
	Umbra = { Color3.fromRGB(79, 33, 145), Color3.fromRGB(20, 20, 20) },
	Radiant = { Color3.fromRGB(245, 194, 48), Color3.fromRGB(240, 240, 240) },
	Toxin = { Color3.fromRGB(128, 212, 33), Color3.fromRGB(0, 122, 94) },
}

----------------------------------------------------------------------------------------------------
-- validation
----------------------------------------------------------------------------------------------------
-- Every KeyCode name the engine knows, built once. A "key" value is checked against this rather
-- than by indexing Enum.KeyCode, which errors on a name it does not recognise.
local KEY_NAMES = {}
for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
	KEY_NAMES[item.Name] = item
end

--- Bring any value into the shape its definition allows. Never errors: anything unusable becomes
--- the default, which is what makes a corrupt or out-of-date save harmless.
function Settings.Coerce(def, v)
	if def.Kind == "bool" then
		if type(v) == "boolean" then return v end
		return def.Default
	elseif def.Kind == "number" then
		if type(v) ~= "number" or v ~= v then return def.Default end       -- v ~= v catches NaN
		local step = def.Step or 1
		v = def.Min + math.floor((v - def.Min) / step + 0.5) * step
		return math.clamp(v, def.Min, def.Max)
	elseif def.Kind == "option" then
		if type(v) ~= "number" then return def.Default end
		v = math.floor(v + 0.5)
		if v < 1 or v > #def.Options then return def.Default end
		return v
	elseif def.Kind == "key" then
		if type(v) ~= "string" or #v > 24 then return def.Default end
		if v == "None" then return v end
		-- the old test was `Enum.KeyCode[v] ~= nil` (2026-09-21), which never got to run: indexing an
		-- Enum with a name it does not know RAISES rather than returning nil, so one bad key name in a
		-- save threw straight out of Sanitise and took the whole load or push with it.
		return KEY_NAMES[v] and v or def.Default
	end
	return def.Default
end

--- Every id, coerced, with anything unknown dropped. Both ends run this: the client on what the
--- server sends it, the server on what the client pushes back.
function Settings.Sanitise(tbl)
	local out = {}
	for _, def in ipairs(D) do
		local v = (type(tbl) == "table") and tbl[def.Id] or nil
		out[def.Id] = (v == nil) and def.Default or Settings.Coerce(def, v)
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- the store
----------------------------------------------------------------------------------------------------
local values = {}
for _, def in ipairs(D) do
	values[def.Id] = def.Default
end

local listeners = {}          -- [id or "*"] = { fn, ... }
local loaded = false          -- has the server's copy arrived yet
local pushDirty = false
local pushAt = 0

function Settings.Get(id)
	local v = values[id]
	if v == nil then
		local def = Settings.ById[id]
		return def and def.Default or nil
	end
	return v
end

--- The value as a 0..1 fraction of its range -- what most appliers actually want from a percentage.
function Settings.Fraction(id)
	local def = Settings.ById[id]
	if not def or def.Kind ~= "number" then return 0 end
	return (Settings.Get(id) - def.Min) / math.max(1e-6, def.Max - def.Min)
end

--- A "100 means unchanged" percentage as a multiplier.
function Settings.Scale(id)
	return Settings.Get(id) / 100
end

----------------------------------------------------------------------------------------------------
-- curves (Build Prompt #25)
----------------------------------------------------------------------------------------------------
-- A slider's number is where the knob sits; what it DOES is shaped for how the effect is felt. Three shapes:
--   Curve = { Low, High }  a multiplier, exponential either side of the middle: Low at Min, exactly 1.0 at the middle,
--                          High at Max. Every step is the same ratio, which is how turn speed is perceived.
--   Track = "log"          the knob moves along a logarithmic track, so each stretch of slider is the same RATIO of a size
--                          or a percentage (50% -> 100% is as much slider as 100% -> 200%). The stored value is still
--                          the plain number the row shows.
--   Loudness = true        a 0..100 volume turned into gain so that perceived loudness, not amplitude, is linear.
local function curveAt(def, v)
	local mid = (def.Min + def.Max) / 2
	local half = math.max(1e-6, (def.Max - def.Min) / 2)
	if v <= mid then
		return def.Curve.Low ^ ((mid - v) / half)
	end
	return def.Curve.High ^ ((v - mid) / half)
end

--- The multiplier a Curve setting stands for (1 for a setting without one).
function Settings.Multiplier(id)
	local def = Settings.ById[id]
	if not def or not def.Curve then return 1 end
	return curveAt(def, Settings.Get(id))
end

--- A volume's gain. Loudness goes as amplitude^0.6, so amplitude = fraction^(1/0.6) makes 50 sound half as loud; a
--- linear gain put the whole top half of the slider inside 6 dB.
function Settings.Gain(id)
	local def = Settings.ById[id]
	local f = Settings.Fraction(id)
	if def and def.Loudness then
		return f ^ (5 / 3)
	end
	return f
end

--- Knob position (0..1) for a value, and the value at a knob position, honouring Track = "log".
function Settings.ToTrack(def, v)
	if def.Track == "log" and def.Min > 0 then
		return math.log(v / def.Min) / math.log(def.Max / def.Min)
	end
	return (v - def.Min) / math.max(1e-6, def.Max - def.Min)
end

function Settings.FromTrack(def, t)
	t = math.clamp(t, 0, 1)
	if def.Track == "log" and def.Min > 0 then
		return def.Min * (def.Max / def.Min) ^ t
	end
	return def.Min + t * (def.Max - def.Min)
end

--- What a slider's readout should say when its plain number would mislead: a Curve setting shows its multiplier.
function Settings.Readout(def, v)
	if def.Curve then
		return ("%.2fx"):format(curveAt(def, v))
	end
	return nil
end

function Settings.KeyCode(id)
	local name = Settings.Get(id)
	return (name and name ~= "None") and KEY_NAMES[name] or nil
end

function Settings.ElementColor(name)
	local pair = Settings.ElementColors[name]
	if not pair then return Color3.fromRGB(245, 184, 0) end
	return Settings.Get("ColorblindSafe") and pair[2] or pair[1]
end

local function fire(id, value)
	for _, fn in ipairs(listeners[id] or {}) do
		local ok, err = pcall(fn, value, id)
		if not ok then warn("[Settings] listener for " .. id .. ": " .. tostring(err)) end
	end
	for _, fn in ipairs(listeners["*"] or {}) do
		local ok, err = pcall(fn, id, value)
		if not ok then warn("[Settings] listener: " .. tostring(err)) end
	end
end

local function connect(id, fn)
	listeners[id] = listeners[id] or {}
	table.insert(listeners[id], fn)
	return {
		Disconnect = function()
			for i, f in ipairs(listeners[id]) do
				if f == fn then table.remove(listeners[id], i) break end
			end
		end,
	}
end

--- Set a value. `silent` skips the save push -- used by the load path, which is applying what was
--- saved rather than making a change worth saving.
function Settings.Set(id, v, silent)
	local def = Settings.ById[id]
	if not def then
		warn("[Settings] no such setting: " .. tostring(id))
		return
	end
	v = Settings.Coerce(def, v)
	if values[id] == v then return end
	values[id] = v
	if not silent then
		pushDirty = true
		pushAt = os.clock() + Settings.PushDebounce
	end
	fire(id, v)
end

function Settings.OnChange(id, fn)
	return connect(id, fn)
end

--- The one most callers want: apply it now, and again whenever it changes.
function Settings.Bind(id, fn)
	fn(Settings.Get(id), id)
	return connect(id, fn)
end

function Settings.OnAnyChange(fn)
	return connect("*", fn)
end

function Settings.Snapshot()
	local out = {}
	for k, v in pairs(values) do out[k] = v end
	return out
end

function Settings.IsLoaded()
	return loaded
end

--- Replace everything from a saved table. Only ids whose value actually moves fire a listener, so a
--- load is silent for anything already at the saved value.
function Settings.Load(tbl)
	local clean = Settings.Sanitise(tbl)
	for id, v in pairs(clean) do
		Settings.Set(id, v, true)
	end
	loaded = true
	for _, fn in ipairs(listeners.__loaded or {}) do
		pcall(fn)
	end
end

--- Call fn once the saved values have arrived (immediately, if they already have).
function Settings.OnLoaded(fn)
	if loaded then fn() return end
	return connect("__loaded", fn)
end

function Settings.Reset()
	for _, def in ipairs(D) do
		Settings.Set(def.Id, def.Default)
	end
end

----------------------------------------------------------------------------------------------------
-- persistence (the caller does the talking)
----------------------------------------------------------------------------------------------------
--- A snapshot when one is due to be saved, nil otherwise. SettingsRuntime polls this on Heartbeat
--- and sends what it gets; the debounce means a slider drag is one message and not one per frame.
function Settings.TakePush()
	if not pushDirty or os.clock() < pushAt then return nil end
	pushDirty = false
	return Settings.Snapshot()
end

--- Everything loaded, without marking anything to save -- used when the module has to be told the
--- save is already up to date.
function Settings.MarkSaved()
	pushDirty = false
end

return Settings
