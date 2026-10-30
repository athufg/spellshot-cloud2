--[[
	RadiantFX_Hand  (ReplicatedStorage.IceMagic.RadiantFX_Hand, ModuleScript, CLIENT ONLY)   Radiant Phase 5, 2026-09-29

	The three HAND pieces of the owner-confirmed Phase 4 round-3 designs, ported from their Blender frame_fn(t) onto
	RadiantDraw (same folder):
	  BLESSING        phase4_r3/blessing/blessing_r2.py        + hand_common.py / hand_r2.py (the Seraph Seal)
	  OVERFLOW LIGHT  phase4_r3/overflow_light/overflow_light_r2.py  (frame = the payoff, frame_empty = EMPTIED)
	  POSITION TRADE  phase4_r3/position_trade/position_trade_r2.py
	Every schedule, level, radius and seed below is the Blender script's; the geometry of the Seal is the demo ally's
	(keys.json seal_geometry), measured from the floor under the HumanoidRootPart (root - 3.0, the kit's ROOT_H).

	API (the integrator calls these from RadiantClient's handlers; each is safe to call with a partial payload and
	returns its effect state, for diagnostics only)
	  Hand.Blessing(d)   RadiantBlessing {Character, Target, T0}. Target == Character: the seal on the caster, no Bond.
	                     A Blessing on a target whose seal is already up keeps the seal and re-lands on it (a refresh).
	  Hand.Overflow(d)   RadiantOverflow {Character (the recipient), Caster (UserId), Amount}: the payoff. With no seal
	                     on this client (joined late / streamed) it plays from a full seal.
	  Hand.TradeOut(d)   RadiantTradeOut {Character, Other, From, To, T0, Dissolve}
	  Hand.TradeIn(d)    RadiantTradeIn  {Character, Other, A, B, T0 | Cancelled}
	  Hand.Handlers      { RadiantBlessing = .., RadiantOverflow = .., RadiantTradeOut = .., RadiantTradeIn = .. }
	  Hand.SetStaffHook(fn)   fn(character, key, level, visible) -> staff tip Vector3 | nil. Called every frame of a
	                     staff moment (Blessing's pulse, Overflow's flash, Trade's gather/flash) with the kit's
	                     staff_glow level 0..1; visible=false while Trade hides the bodies; level=nil = released (key,
	                     a table, is one effect: combine several with max). The staff owner applies RD.StaffGlow; a
	                     returned tip gets the kit's staff_aura (tip glint, sparkles, light) on this effect's budget.
	                     No hook: no staff visuals at all.
	  Hand.StopAll()     every effect ends on its next frame (bodies shown, highlights removed)
	  Hand.PrewarmDevil()   builds the Devil skin's forms ahead (see THE DEVIL SKIN below; optional)
	  Hand.Config
	THE BLESSED STATUS: the shield lives exactly as long as the recipient's RX_Blessed attribute (StatusEffects'
	contract: RX_Blessed flag, _Amount, _Expires ...). It is polled every frame. RX_Blessed going false with no
	RadiantOverflow within Config.StatusGrace = the EMPTIED look (emptied by damage, cleared, or lapsed with nothing to
	heal); RadiantOverflow (before or after the flag) = the payoff.

	CLOCKS. Blessing: server time from T0 (RD.Clock), so every client draws the same phase. Overflow: from receipt
	(the payload has no T0; clip 0.22 shown at receipt, payoff 0.25). Trade: from RECEIPT, re-anchored at TradeIn (the
	client sees the teleport when the swap replicates, i.e. at TradeIn's receipt): clip [TradeClipAtOut=0.12, 0.36] is
	played over the server's Dissolve (2x: the Blender anticipation before the dissolve cannot happen before the
	broadcast), then from 0.36 at TradeIn at 1x. A late TradeIn holds the contracted lines; none within
	Dissolve + TradeInWait drops the effect.
	The Seal's slow turn, the halo bob, the ray breathing and the glitter run on ONE clock per shield (its first T0),
	so a refresh, an Overflow or an EMPTIED ending never jumps.

	NOT LIKE BLENDER: RadiantDraw's limits (no thickness, straight-ramp tapers, 8-point glints, round motes, hash
	randomness, no floor disc, uncalibrated bloom), plus: camera-facing rings are Catmull-Rom through <= 16 knots per
	circle (0.2% radius error; ~1% at the seam, which is turned away from the viewer); the aureole is 12 knots per side;
	Blessing's landing time is computed from an estimated raised-palm point (the kit's pose at t 0.5 is not available);
	the Trade anticipation runs at 2x; a Trade's spots follow the live bodies until the swap, then the server's A / B.

	THE DEVIL SKIN (2026-10-13; radiant_devil_skin_2026_10_12: kit/devil_look.py's overrides + mk_devil.py's per-piece
	edits). THE GATE: an effect whose canvas wears the Devil palette (cv.Palette.Id == "Devil": the caster's Blessing /
	Position Trade skin, handed in by RadiantClient's WithPalette) gets a RadiantDevilForge scope, st.dsc, and draws the
	devil forms in place of the angelic ones; Default and Rainbow never make one and draw exactly as before (a missing
	forge module: the Devil palette's crimson recolour only).
	  BLESSING   the aureole arches -> Forge.HornDome (7 black-iron horns rising out of the floor and arching over the
	             head, their seams on the arch level); the floor ring -> Forge.SealPlate (the carved pentagram plate);
	             the girdle a dark band (level x 0.45) with 10 crimson runes once it closes; the clasps grow two small
	             horns (Forge.ClaspHorns); no halo (the dome closes over the head); the Bond -> Forge.DevilBond (a dark
	             thread, barbed chevrons gliding to the ally, embers, a small inverted pentagram at the source).
	  OVERFLOW   the dashes -> the horn dome crumbling to ash (frag = the dash duty) while the motes stream into the
	             chest; the chest's sun rosette -> Forge.ChestBrand (a carved plate that flares as the heal lands, cools
	             and stays). EMPTIED: the dome sinks back into the floor, the plate shrinks.
	  TRADE      the body gather, the lantern cages, the axis lines and the apex glint -> Forge.Maw per spot (a fanged
	             maw + four claws; embers boil from it); the gold body glow -> a dark crimson TINT (Config.DevilTint, an
	             alpha-blended Highlight: added red over a pale body reads pink); the bridge a taut barbed DevilBond.
	  every one  the sigils -> small inverted pentagrams; no shock ring on any flare.
]]

local Players = game:GetService("Players")

local RD = require(script.Parent:WaitForChild("RadiantDraw"))

local Hand = {}

----------------------------------------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------------------------------------
local Config = {
	ArcSpanLen = 0.9,          -- camera-facing rings: one Catmull-Rom span per ~this many studs of circle ...
	ArcMinSpans = 8,           -- ... clamped to 8..16 spans per full circle
	ArcMaxSpans = 16,
	ArchSamples = 12,          -- aureole knots per side
	RootHeight = 3.0,          -- the kit's ROOT_H: the floor is this far under the HumanoidRootPart
	StatusGrace = 0.2,         -- s: RX_Blessed off -> wait this long for RadiantOverflow before the EMPTIED look
	FlagWait = 1.0,            -- s: a shield whose RX_Blessed never shows on this client ends (EMPTIED) after this
	BlessMaxLife = 120,        -- s: RadiantDraw's hard stop for one shield (refreshes included)
	SelfLandT = 0.436,         -- Blessing with no Bond: the clip second the seal starts (the demo's landing)
	OverflowFrom = 0.22,       -- the Overflow clip second shown at the RadiantOverflow receipt (the payoff is 0.25)
	TradeClipAtOut = 0.12,     -- the Trade clip second shown at the RadiantTradeOut receipt
	TradeInWait = 1.0,         -- s past the Dissolve with no RadiantTradeIn: the trade is dropped
	HighlightMax = 0.8,        -- Trade body glow: FillTransparency = 1 - HighlightMax x level^1.2 (0.2 at the flash)
	GlowColor = Color3.fromRGB(245, 194, 48),   -- #F5C230
	DevilTint = Color3.fromHex("#7A0C14"),      -- Devil Trade: the bodies tint toward this (devil_look body_glow) ...
	DevilTintMax = 0.7,                         -- ... FillTransparency = 1 - DevilTintMax x level^1.2
	FXFolderName = "IceMagicFX",
	FloorLift = 0.04,          -- flat floor linework sits this far over the floor
}
Hand.Config = Config

----------------------------------------------------------------------------------------------------
-- MATHS
----------------------------------------------------------------------------------------------------
local ramp, env, clamp, lw, eob, ease = RD.ramp, RD.env, RD.clamp, RD.lw, RD.ease_out_back, RD.ease
local sin, cos, abs, max, min, sqrt, floor, ceil, pi = math.sin, math.cos, math.abs, math.max, math.min, math.sqrt,
	math.floor, math.ceil, math.pi
local TAU = 2 * pi
local UP = RD.UP
local EX, EY = RD.B(1, 0, 0), RD.B(0, 1, 0)      -- the kit's horizontal ring basis: angle 0 = Blender +X
local FWD0 = RD.B(0, -1, 0)                      -- the kit's no-camera fallback direction
local HEAD_TAPER = RD.Config.HEAD_TAPER or 0.3

local function spow(x, e)
	if x >= 0 then return x ^ e end
	return -((-x) ^ e)
end

local function hor(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function unitOr(v, fb)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return fb
end

local function ringDir(a)
	return EX * cos(a) + EY * sin(a)
end

local function azim(d)
	return math.atan2(d:Dot(EY), d:Dot(EX))
end

--- the kit's rotz(v, deg) about the vertical (right-handed; Blender Z -> Roblox Y keeps the sense)
local function rotY(v, a)
	return v * cos(a) + UP:Cross(v) * sin(a)
end

local function arcPieces(sw)
	return max(1, ceil(abs(sw) / (pi / 2) - 1e-6))
end

local function spansFor(r)
	return clamp(ceil(TAU * r / Config.ArcSpanLen), Config.ArcMinSpans, Config.ArcMaxSpans)
end

local function trim(t, n)
	for i = #t, n + 1, -1 do t[i] = nil end
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[RadiantFX_Hand] " .. msg)
end

----------------------------------------------------------------------------------------------------
-- THE SERAPH SEAL's geometry (hand_r2.py; the demo ally, heights over the floor)
----------------------------------------------------------------------------------------------------
local S_GZ, S_GR, S_A, S_N, S_BACK = 3.35, 2.2, 2.3, 2.4, 0.6
local S_HEAD_TOP = 5.195                          -- the demo's head top (Head z + 0.575)
local S_TOP = S_HEAD_TOP + 0.45                   -- 5.645: the aureole closes here (the halo)
local S_BOTTOM = -0.8
local S_ZC, S_B = (S_TOP + S_BOTTOM) / 2, (S_TOP - S_BOTTOM) / 2
local S_E = 2 / S_N
local S_TURN = 16                                 -- deg/s
local S_NCLASP = 3
local S_HALO_R = 0.42
local TH_F = -math.asin(clamp((S_ZC / S_B) ^ (S_N / 2), 0, 1))           -- aureole angle at the floor
local TH_G = math.asin(spow((S_GZ - S_ZC) / S_B, S_N / 2))               -- ... at the girdle
local S_SG = (TH_G - TH_F) / (pi / 2 - TH_F)                             -- arch draw fraction at the girdle
local XF = S_A * max(0, cos(TH_F)) ^ S_E
local S_RF = sqrt(XF * XF + S_BACK * S_BACK)                             -- the floor ring (the arches' feet)

-- BLESSING (blessing_r2.py)
local B_B0, B_B1 = 0.22, 0.48                     -- the Bond draws on (Linear)
local B_MIG0, B_MIGD = 0.80, 0.45                 -- the Bond's source slides palm -> chest

-- OVERFLOW (overflow_light_r2.py)
local O_TB = 0.25
local O_TCL = { 0.33, 0.40, 0.47 }                -- clasp k starts to loosen
local O_COL0, O_COLD, O_SEND = 0.55, 0.45, 0.22   -- the seal contracts to 0.22 toward the chest front
local O_DASH0, O_DASHD = 0.72, 0.24
local O_REEL0, O_REELD = 0.40, 0.30
local O_TIN = 1.04
local O_DUR, E_DUR = 2.0, 0.9
local N_GD, N_AD = 10, 12
local MOTE_T = 0.14
local STEADY = { girdle = 0.55, arches = 0.4, clasps = 0.62, halo = 0.7, rays = 0.5, ground = 0.32 }
local PAYOFF = { girdle = 1.0, arches = 0.75, clasps = 1.0, halo = 1.0, rays = 0.8, ground = 0.6 }
local TC = {}                                     -- dash j turns into a mote (random.Random(29).uniform(.88, .97))
for j = 1, N_GD + N_AD do TC[j] = 0.88 + 0.09 * RD.Rand(29, j, 1) end

-- POSITION TRADE (position_trade_r2.py)
local P_D0, P_FLASH = 0.24, 1 / 30
local P_SWAP = P_D0 + 0.12
local P_R1 = P_SWAP + 0.12
local P_BR0, P_BRD = P_D0 + 0.015, 0.075
local P_RT0, P_RTD = P_SWAP, 0.10
local P_DIS0, P_DISD = P_R1 + 0.03, 0.32
local P_DUR = 1.3
local CAGE = { { 0.05, 1.1 }, { 1.6, 1.25 }, { 3.1, 1.35 }, { 4.75, 0.72 } }
local APEX = 5.45
local BRIDGE_Z = 3.35
local BURST_SEED, SPARK_SEED = { 24, 174 }, { 12, 27 }     -- the demo's int(x*10+99) / int(x+20) at x = -7.5 / 7.5

----------------------------------------------------------------------------------------------------
-- SCENE QUERIES
----------------------------------------------------------------------------------------------------
local camPos, camLook = Vector3.new(0, 5, 20), Vector3.new(0, 0, -1)

local function camRead()
	local c = workspace.CurrentCamera
	if c then
		local cf = c.CFrame
		camPos, camLook = cf.Position, cf.LookVector
	end
end

local function rootOf(m)
	if typeof(m) ~= "Instance" or m.Parent == nil then return nil end
	return m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
end

local function chestOf(m, root)
	local p = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
	if p then return p.Position end
	return root.Position + UP * 0.85
end

local vm = nil                                    -- IceMagic.Viewmodel, required lazily (false: unavailable)
local function viewmodel()
	if vm == nil then
		vm = false
		local mod = script.Parent:FindFirstChild("Viewmodel")
		if mod then
			local ok, v = pcall(require, mod)
			if ok and type(v) == "table" then vm = v end
		end
	end
	return vm or nil
end

--- the kit's palm_src(fig): the open LEFT palm + 0.12 along its normal, and the normal. The local caster in first
--- person: the viewmodel's left fist, looking along the forearm.
local function palmOf(m)
	local lp = Players.LocalPlayer
	if lp and m == lp.Character then
		local v = viewmodel()
		if v and type(v.GetFistCFrame) == "function" then
			local ok, cf = pcall(v.GetFistCFrame, "L")
			if ok and typeof(cf) == "CFrame" then return cf.Position + cf.LookVector * 0.12, cf.LookVector end
		end
	end
	local h = m:FindFirstChild("LeftHand")
	if h then
		local c, n = RD.Palm(h.CFrame)
		return c + n * 0.12, n
	end
	local a = m:FindFirstChild("Left Arm")
	if a then
		local c, n = RD.Palm(a.CFrame * CFrame.new(0, -0.85, 0))
		return c + n * 0.12, n
	end
	return nil, nil
end

local fxFolderRef = nil
local function fxFolder()
	if fxFolderRef and fxFolderRef.Parent then return fxFolderRef end
	local name = Config.FXFolderName
	local mod = script.Parent:FindFirstChild("VFXLibrary")
	if mod then
		local ok, lib = pcall(require, mod)
		if ok and type(lib) == "table" and type(lib.Config) == "table" and type(lib.Config.FXFolderName) == "string" then
			name = lib.Config.FXFolderName
		end
	end
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	fxFolderRef = f
	return f
end

----------------------------------------------------------------------------------------------------
-- THE DEVIL SKIN: RadiantDevilForge (same folder), required lazily. Its helpers live in this ONE table: the chunk
-- sits near Studio's 200-locals limit.
----------------------------------------------------------------------------------------------------
local Devil = { F = nil, Warmed = {}, NoShock = {}, BlessWarm = { "Blessing", "Overflow" },
	OverflowWarm = { "Overflow" }, TradeWarm = { "Trade" }, CLH = { r = 0.18, level = 0.6, u = 1, front = nil } }

--- the forge module, or nil (missing or failed: a Devil palette then draws the crimson recolour only)
function Devil.Forge()
	if Devil.F == nil then
		Devil.F = false
		local mod = script.Parent:FindFirstChild("RadiantDevilForge")
		if mod then
			local ok, f = pcall(require, mod)
			if ok and type(f) == "table" then
				Devil.F = f
			else
				warnOnce("forge", "RadiantDevilForge failed: " .. tostring(f))
			end
		end
	end
	return Devil.F or nil
end

--- THE GATE: a forge scope for an effect whose canvas wears the Devil palette (Forge.IsDevil: pal.Id == "Devil"),
--- else nil -- Default and Rainbow never load the forge. The first Devil effect of a kind builds its pieces' forms
--- ahead (Forge.PrewarmPiece, once per client): the dome rises 0.3-0.6 s into the cast, the chest plate 0.8 s into
--- the Overflow, so they are built by then; the Trade's maws show at once (its first cast: a few frames late).
function Devil.Scope(cv, name, warm)
	local pal = cv and cv.Palette
	if not (type(pal) == "table" and pal.Id == "Devil") then return nil end
	local F = Devil.Forge()
	if not F then return nil end
	Devil.Warm(F, warm)
	return F.Scope(name)
end

--- Forge.PrewarmPiece for each piece not yet warmed on this client
function Devil.Warm(F, pieces)
	for _, piece in ipairs(pieces) do
		if not Devil.Warmed[piece] then
			Devil.Warmed[piece] = true
			pcall(F.PrewarmPiece, piece)
		end
	end
end

--- a flare's options with no shock ring when sc (devil_look's flare: "no shock ring on any flare")
function Devil.Flare(o, sc)
	if not sc or o.shock == false then return o end
	local d = Devil.NoShock[o]
	if not d then
		d = table.clone(o)
		d.shock = false
		Devil.NoShock[o] = d
	end
	return d
end

--- the kit's bond, or (sc) THE DEVIL BOND: a dark iron thread drawn on by u, barbed chevrons gliding to dst, embers
--- rising off it, a small inverted pentagram at the source (the same options; pulse == false: a taut contract line)
function Devil.Bond(cv, sc, src, dst, u, level, o)
	if sc then return Devil.F.DevilBond(cv, src, dst, u, level, o) end
	return cv:Bond(src, dst, u, level, o)
end

----------------------------------------------------------------------------------------------------
-- THE STAFF HOOK
----------------------------------------------------------------------------------------------------
local staffHook = nil

function Hand.SetStaffHook(fn)
	staffHook = (type(fn) == "function") and fn or nil
end

local function staffCall(st, c, level, visible)
	if not (staffHook and c) then return nil end
	st.staffC = c
	local ok, tip = pcall(staffHook, c, st, level, visible)
	if not ok then
		warnOnce("staff", "StaffHook failed: " .. tostring(tip))
		return nil
	end
	return (typeof(tip) == "Vector3") and tip or nil
end

--- the kit's staff_aura at the hook's tip. Its sparkles (size 0.1 x level) are skipped below level 0.25, where they
--- are under 0.025 studs: that keeps Position Trade's reform (bursts + sparkles + apex glints) inside 40 glints.
local AURA_O = { sparkle = true }
local function aura(cv, tip, level, t)
	if level <= 0.02 then return end
	AURA_O.sparkle = level >= 0.25
	cv:StaffAura(tip, level, t, AURA_O)
end

local function staffRelease(st)
	local c = st.staffC
	if staffHook and c then
		st.staffC = nil
		pcall(staffHook, c, st, nil, true)
	end
end

----------------------------------------------------------------------------------------------------
-- CAMERA-FACING BANDS (hand_r2's cam_band / loop_pts: a Beam's look along a curve)
----------------------------------------------------------------------------------------------------
local PTS, FINE, HST = {}, {}, {}
local SO = { w = nil, smooth_k = 1, taper = nil, lo = { 0, 0.35 }, pieces = 0 }   -- counted by the caller
local SO_TAPER = { 0, 0 }
local HEAD_TRAIL = { w = lw(1) * 1.45 }

--- PTS[1..n] as one camera-facing band (Catmull-Rom through the knots); head: tapered drawing end
local function band(cv, n, level, w, head)
	trim(PTS, n)
	if n < 2 then return false end
	SO.w = w
	if head then
		local L = 0
		for i = 2, n do L += (PTS[i] - PTS[i - 1]).Magnitude end
		SO_TAPER[2] = min(HEAD_TAPER, L * 0.3)
		SO.taper = SO_TAPER
	else
		SO.taper = nil
	end
	cv:Stroke(PTS, level, SO)
	return true
end

--- a horizontal arc into PTS (loop_pts): angle a0, sweep, radius r round c -> knot count
local function arcPts(c, r, a0, sweep, spans)
	spans = spans or max(1, ceil(abs(sweep) / TAU * spansFor(r) - 1e-6))
	for j = 0, spans do
		PTS[j + 1] = c + ringDir(a0 + sweep * j / spans) * r
	end
	return spans + 1
end

--- a whole horizontal ring, its seam on the far side from this viewer
local function loopBand(cv, c, r, level, w)
	band(cv, arcPts(c, r, azim(c - camPos), TAU, spansFor(r)), level, w, false)
end

--- the kit's _head on a polyline pts[1..n]: its last min(0.9, 0.6 x length) burns as a trail, a glint on its tip
local function polyHead(cv, pts, n, t)
	local tot = 0
	for i = 2, n do tot += (pts[i] - pts[i - 1]).Magnitude end
	if tot < 0.05 then return end
	local hl = min(0.9, tot * 0.6)
	local acc, i = 0, n
	while i > 1 do
		local l = (pts[i] - pts[i - 1]).Magnitude
		if acc + l >= hl then break end
		acc += l
		i -= 1
	end
	local k = 0
	if i > 1 then
		local l = (pts[i] - pts[i - 1]).Magnitude
		k = 1
		HST[1] = pts[i] + (pts[i - 1] - pts[i]) * ((hl - acc) / max(l, 1e-9))
	end
	for j = i, n do
		k += 1
		HST[k] = pts[j]
	end
	trim(HST, k)
	if k >= 2 then cv:Trail(HST, 1.0, HEAD_TRAIL) end
	cv:Glint(pts[n], 0.2, 1.0, 2 * t, nil, 0.45)
end

----------------------------------------------------------------------------------------------------
-- THE SEAL (hand_r2.Seal): a per-frame state F, then its parts
----------------------------------------------------------------------------------------------------
local function newFrame()
	return { x = 0, z = 0, fy = 0, fwd = FWD0, turn = 0, s = 1, pivot = Vector3.new(0, 0, 0), K = Vector3.new(0, 0, 0),
		vd = FWD0, vx = EX }
end

--- F from the ally's live root: position, floor, forward, chest; the viewer's yaw-only billboard (aureole, rays)
local function sealRead(F, model)
	local r = rootOf(model)
	if not r then return false end
	local cf = r.CFrame
	local p = cf.Position
	F.x, F.z, F.fy = p.X, p.Z, p.Y - Config.RootHeight
	F.fwd = unitOr(hor(cf.LookVector), FWD0)
	F.K = chestOf(model, r)
	local d = hor(camPos - Vector3.new(F.x, F.fy + S_ZC, F.z))
	-- the viewer on the ally's own axis (its first person): "toward the viewer" = the look, so the aureole and the
	-- rays stand behind the camera
	if d.Magnitude < 0.5 then d = hor(camLook) end
	F.vd = unitOr(d, FWD0)
	F.vx = UP:Cross(F.vd).Unit
	F.s, F.pivot = 1, F.K
	return true
end

local function copyFrame(D, F)
	D.x, D.z, D.fy, D.fwd, D.K, D.vd, D.vx = F.x, F.z, F.fy, F.fwd, F.K, F.vd, F.vx
end

local function X(F, p)
	if F.s == 1 then return p end
	return F.pivot + (p - F.pivot) * F.s
end

local function gc(F)
	return Vector3.new(F.x, F.fy + S_GZ, F.z)
end

local function topPt(F)
	return X(F, Vector3.new(F.x, F.fy + S_TOP, F.z))
end

--- aur_pt: side +1 / -1 (viewer right / left), s 0 (the floor) .. 1 (the top)
local function aurPt(F, side, s)
	local th = TH_F + (pi / 2 - TH_F) * s
	local o = Vector3.new(F.x, F.fy + S_ZC, F.z) - F.vd * S_BACK
	return X(F, o + F.vx * (side * S_A * spow(cos(th), S_E)) + UP * (S_B * spow(sin(th), S_E)))
end

--- a point of the whole closed aureole (aur_loop) at loop angle a (pi/2 = the top)
local function aurLoopPt(F, a)
	local o = Vector3.new(F.x, F.fy + S_ZC, F.z) - F.vd * S_BACK
	return X(F, o + F.vx * (S_A * spow(cos(a), S_E)) + UP * (S_B * spow(sin(a), S_E)))
end

--- clasp j (0..2): point, axis, outward (120 deg apart on the girdle, orbiting with the turn)
local function claspAt(F, j)
	local e = rotY(F.fwd, math.rad(F.turn + 60 + j * 360 / S_NCLASP))
	return X(F, gc(F) + e * S_GR), UP:Cross(e).Unit, e
end

--- sc (a Devil forge scope; the same for arches, clasps, halo, ground): devil_look's Seal override instead
local function girdle(cv, F, level, phi, wrap, heads, t, sc)
	if wrap <= 0 then return end
	if sc then
		-- (Devil) the runed black-iron band: the girdle dark (level x 0.45), 10 crimson runes on it once it closes
		-- (hand_r2 girdle_dashes(min(1, level x 1.25), 10, 0.14))
		girdle(cv, F, level * 0.45, phi, wrap, heads, t)
		if wrap < 0.999 or level <= 0.15 then return end
		local c, r = X(F, gc(F)), S_GR * F.s
		local a0, hw, lv, k = math.rad(F.turn), pi / 10 * 0.14, min(1, level * 1.25), 0
		for j = 0, 9 do
			if band(cv, arcPts(c, r, a0 + j * TAU / 10 - hw, 2 * hw), lv, nil, false) then k += 1 end
		end
		cv:Count(k)
		return
	end
	local c, r = X(F, gc(F)), S_GR * F.s
	if wrap >= 1 then
		loopBand(cv, c, r, level, nil)
		cv:Count(1)
		return
	end
	for sg = 1, -1, -2 do
		local sw = sg * pi * wrap
		band(cv, arcPts(c, r, phi, sw), level, nil, true)
		cv:Count(arcPieces(sw))
		if heads then
			local tot = abs(sw) * r
			if tot >= 0.05 then
				local da = min(0.9, tot * 0.6) / r
				for j = 0, 4 do FINE[j + 1] = c + ringDir(phi + sw - sg * da * (1 - j / 4)) * r end
				trim(FINE, 5)
				cv:Trail(FINE, 1.0, HEAD_TRAIL)
				cv:Glint(FINE[5], 0.2, 1.0, 2 * t, nil, 0.45)
			end
		end
	end
end

local function arches(cv, F, level, u, heads, t, sc)
	if u <= 0 then return end
	-- (Devil) the aureole -> the horn dome: rising out of the floor with u, its seams on the arch level. (2026-10-19,
	-- audit P5C-02) while the dome's mesh is still building, or failed, the Default arches below are drawn instead
	if sc and Devil.F.Drawn(Devil.F.HornDome, sc, F, level, u, t) then return end
	local AS = Config.ArchSamples
	if u >= 1 then
		local n = 0
		for j = 0, AS do
			n += 1
			PTS[n] = aurPt(F, 1, j / AS)
		end
		for j = AS - 1, 0, -1 do
			n += 1
			PTS[n] = aurPt(F, -1, j / AS)
		end
		band(cv, n, level, nil, false)
		cv:Count(1)
		return
	end
	for side = 1, -1, -2 do
		local m = max(3, ceil(AS * u))
		for j = 0, m do PTS[j + 1] = aurPt(F, side, u * j / m) end
		band(cv, m + 1, level, nil, true)
		cv:Count(arcPieces((pi / 2 - TH_F) * u))
		if heads then
			local mf = max(8, ceil(40 * u))
			for j = 0, mf do FINE[j + 1] = aurPt(F, side, u * j / mf) end
			trim(FINE, mf + 1)
			polyHead(cv, FINE, mf + 1, t)
		end
	end
end

local CLO = { r = 0.18, width = 0.3, level = 0.6, u = 1, front = nil, th = 0.05 }
local function clasps(cv, F, us, level, loosen, sc)
	for j = 0, S_NCLASP - 1 do
		local u = us[j + 1]
		if u > 0 then
			local lo = loosen and loosen[j + 1] or 0
			local p, ax, e = claspAt(F, j)
			CLO.r, CLO.width, CLO.level, CLO.u, CLO.front = 0.18 * (1 + 0.9 * lo), 0.3 * (1 - 0.25 * lo), level, u, e
			cv:Clasp(p + e * (0.1 * lo), ax, CLO)
			if sc then                                   -- (Devil) HORNED clasps: two small curved horns off its sides
				local o = Devil.CLH
				o.r, o.level, o.u, o.front = CLO.r, level, u, e
				Devil.F.ClaspHorns(cv, p + e * (0.1 * lo), ax, o)
			end
		end
	end
end

local function halo(cv, F, u, level, t, lift, sc)
	if u <= 0 or sc then return end                  -- (Devil) no halo: the dome's horn tips close over the head
	local g = eob(clamp(u, 0, 1), 1.4)
	local c = topPt(F) + UP * ((lift or 0) * (1 - ramp(u, 0, 1)) + 0.05 * sin(TAU * 0.7 * t))
	local r = S_HALO_R * g * max(F.s, 0.05)
	if r < 0.02 then return end
	loopBand(cv, c, r, level, lw(level) * 1.15)
	cv:Count(1)
	local a = TAU * 0.55 * t
	cv:Glint(c + ringDir(a) * r, 0.15 * g * ramp(u, 0.3, 0.7), min(1, level + 0.3), t, nil, 0)
end

local RAYO = { n = 11, r0 = 0.95, length = 1.9, width = 0.2, normal = FWD0, axis = UP, fan = math.rad(196), level = 0.5,
	seed = 5, t = 0, v = 0 }
local function rays(cv, F, u, level, t, v, length)
	v = v or 0
	if u <= 0 or v >= 1 then return end
	local k = max(F.s, 0.2)
	local c = X(F, Vector3.new(F.x, F.fy + S_HEAD_TOP - 0.55, F.z) - F.vd * (S_BACK + 0.15))
	RAYO.r0, RAYO.length, RAYO.normal, RAYO.level, RAYO.t, RAYO.v = 0.95 * k, (length or 1.9) * k, F.vd, level, t, v
	cv:HolyRays(c, u, RAYO)
end

local GRO = { rigid = true, w = 0.05 }
local function ground(cv, F, s, level, sc)
	if s <= 0.01 then return end
	-- (Devil) the floor ring -> the carved pentagram plate; (2026-10-19, audit P5C-02) the ring while it is not built
	if sc and Devil.F.Drawn(Devil.F.SealPlate, sc, F, s, level) then return end
	GRO.w = lw(level) * 1.1
	cv:Ring(Vector3.new(F.x, F.fy + Config.FloorLift, F.z), S_RF * s * F.s, UP, level, GRO)
end

-- glitter: sparkles on the shell (shell_region) + motes rising from the floor ring
local shellK = 1
local function shellRegion(rnd)
	local z = rnd() * 2 - 1
	local ph = rnd() * TAU
	local rr = sqrt(max(0, 1 - z * z))
	local k = shellK * (0.9 + 0.15 * rnd())
	-- Blender (d.x a, d.y a, max(d.z b, 0.4 - zc)) -> Roblox (-x, z, y)
	return Vector3.new(-rr * cos(ph) * S_A * k, max(z * S_B, 0.4 - S_ZC) * k, rr * sin(ph) * S_A * k)
end
local GLS = { n = 10, seed = 23, level = 0.9, size = 0.13, life = 1.15, t0 = 0, t1 = 1e9, drift = UP * 0.16,
	region = shellRegion }
local GLM = { n = 6, seed = 31, level = 0.8, size = 0.05, rise = 0.9, life = 1.7, t0 = 0, t1 = 1e9 }
local function glitter(cv, F, t, t0, t1)
	shellK = F.s
	GLS.t0, GLS.t1 = t0, t1 or 1e9
	cv:Sparkles(X(F, Vector3.new(F.x, F.fy + S_ZC, F.z)), 1.0, t, GLS)
	GLM.t0, GLM.t1 = t0, t1 or 1e9
	cv:MoteField(Vector3.new(F.x, F.fy + 0.1, F.z), S_RF * 1.1 * F.s, t, GLM)
end

local function sealLight(cv, F, level)
	if level <= 0.01 then return end
	cv:LightPool(Vector3.new(F.x, F.fy + 1.1, F.z) + F.fwd * 1.5, level)
end

-- the Bond's source sigil / the entry seal (hand_common)
-- (sc, Devil: a small inverted pentagram, no sun -- devil_look's src_sigil / draw_seal; 2 pieces)
local SIGO = { spokes = 8, s_in = 1.22, s_out = 1.72, u = 1, w = 0.04, grow = true }
local function srcSigil(cv, p, d, s, level, sc)
	if s > 0.01 then
		if sc then return Devil.F.Pentagram(cv, p + d * 0.03, d, 0.2 * s, level) end
		SIGO.u, SIGO.w = s, lw(level) * 0.78
		cv:Rosette(p, d, 0.36, level, SIGO)
	end
end
local SEALO = { spokes = 6, s_in = 1.21, s_out = 1.79, phase = 0, u = 1, w = 0.04, grow = true }
local function drawSeal(cv, p, d, s, level, sc)
	if s > 0.01 then
		if sc then return Devil.F.Pentagram(cv, p + d * 0.03, d, 0.24 * s, level) end
		SEALO.u, SEALO.w = s, lw(level) * 0.78
		cv:Rosette(p, d, 0.28, level, SEALO)
	end
end

--- where the line src -> dst crosses the girdle's cylinder (radius GR round the ally's axis): point, distance, length
local function cylEntry(F, src, dst)
	local D = dst - src
	local L = D.Magnitude
	if L < 1e-6 then return dst, 0, 0 end
	local d = D / L
	local ox, oz = src.X - F.x, src.Z - F.z
	local qa = d.X * d.X + d.Z * d.Z
	if qa < 1e-8 then return dst, L, L end
	local qb = 2 * (ox * d.X + oz * d.Z)
	local qc = ox * ox + oz * oz - S_GR * S_GR
	local s = (-qb - sqrt(max(qb * qb - 4 * qa * qc, 0))) / (2 * qa)
	s = clamp(s, 0, L)
	return src + d * s, s, L
end

----------------------------------------------------------------------------------------------------
-- BLESSING + OVERFLOW + EMPTIED: one effect per shield (so its turn, bob and glitter never jump)
----------------------------------------------------------------------------------------------------
local shields = setmetatable({}, { __mode = "k" })   -- [recipient model] = its shield while still blessing
local live = {}                                       -- [effect state] = true, every running effect (StopAll)

--- the blessing schedule at clip time tb -> o (also frozen at the end as the EMPTIED look's ceiling)
local function blessState(st, tb, o)
	local pre = st.pre
	local W0 = st.T_W0
	local b = env(tb, W0 - 0.02, W0 + 1.05, 0.08, 0.7)            -- the landing payoff: every line bright
	o.wrap = pre and 1 or ramp(tb, W0, 0.32)
	o.ground = pre and 1 or ramp(tb, W0 + 0.04, 0.36)
	o.arch = pre and 1 or ramp(tb, st.T_ARCH, 0.42)
	for k = 1, S_NCLASP do
		o.clasp[k] = pre and 1 or ramp(tb, st.T_CLASP - 0.03 + 0.05 * (k - 1), 0.24, "Linear")
	end
	o.halo = pre and 1 or ramp(tb, st.T_HALO - 0.08, 0.3)
	o.rays = pre and 1 or ramp(tb, W0 + 0.28, 0.6, "Linear")
	o.bond = (st.Self or not st.Caster) and 0 or clamp((tb - B_B0) / (B_B1 - B_B0), 0, 1)
	o.light = 0.4 * (pre and 1 or ramp(tb, W0 - 0.02, 0.35)) + 0.6 * env(tb, W0 - 0.02, W0 + 0.9, 0.08, 0.6)
	o.lvG = 0.55 + 0.45 * b
	o.lvA = 0.4 + 0.6 * b
	o.lvC = 0.62 + 0.38 * b
	o.lvH = 0.7 + 0.3 * b
	o.lvR = 0.5 + 0.5 * b
	o.lvF = 0.32 + 0.68 * b
	o.lvBond = 0.36 + 0.54 * env(tb, B_B0, W0 + 0.8, 0.06, 0.5)
	return o
end

local function newState()
	return { clasp = { 0, 0, 0 } }
end

local function copyState(d, s)
	for k, v in pairs(s) do
		if k ~= "clasp" then d[k] = v end
	end
	for k = 1, S_NCLASP do d.clasp[k] = s.clasp[k] end
end

--- T_W0 (the Bond's lead reaches the girdle: the seal starts there) and PHI (its azimuth), as the demo computed them
local function landing(st)
	local F = st.F
	local cr = (not st.Self) and rootOf(st.Caster) or nil
	if cr then
		local cc = chestOf(st.Caster, cr)
		local s0 = cc + unitOr(hor(F.K - cc), FWD0) * 1.2 + UP * 0.3   -- about where the raised palm is at 0.5
		local d0 = RD.ReceivePoint(F.K, s0)
		local p, s, L = cylEntry(F, s0, d0)
		st.T_W0 = B_B0 + (B_B1 - B_B0) * clamp(s / max(L, 1e-6), 0, 1)
		st.PHI = azim(p - gc(F))
	else
		st.T_W0 = Config.SelfLandT
		st.PHI = azim(F.fwd)                                         -- traced from the front
	end
	st.T_ARCH = st.T_W0 + 0.10
	st.T_CLASP = st.T_ARCH + 0.42 * math.acos(1 - 2 * S_SG) / pi   -- the arch heads pass the girdle
	st.T_HALO = st.T_ARCH + 0.42                                     -- the arches meet at the top
end

--- the Bond's ends at blessing time tb: the palm's source slides to the caster's chest (0.80 + 0.45)
local function bondEnds(st, c, tb)
	local cc = chestOf(c, rootOf(c))
	local K = st.F.K
	local cs = RD.ReceivePoint(cc, K)
	local src = cs
	if tb < B_MIG0 + B_MIGD then
		local ps = palmOf(c)
		if ps then src = ps + (cs - ps) * ramp(tb, B_MIG0, B_MIGD) end
	end
	return src, RD.ReceivePoint(K, src)
end

local GAO = { radius = 0.85, n = 8, level = 0.95, glint_size = 0.3, t = 0 }
--- the caster's cast: the staff's one soft pulse + the palm gather and its light (blessing_r2 "cast")
local function castParts(st, cv, tb, c)
	cv:Tag("cast")
	if not c then return end
	if tb <= 0.85 then
		local sl = env(tb, 0.12, 0.80, 0.16, 0.42)
		local tip = staffCall(st, c, sl, true)
		if tip then aura(cv, tip, sl, tb) end
	elseif st.staffC then
		staffRelease(st)
	end
	if tb > 1.15 then return end
	local ps, pn = palmOf(c)
	if not ps then return end
	local kp = 1 - ramp(tb, 0.80, 0.30)
	local gu = ramp(tb, 0.02, 0.26)
	if gu > 0 and kp > 0 then
		GAO.glint_size, GAO.t = 0.3 * kp, tb
		cv:Gather(ps, gu, GAO)
	end
	local pl = 0.6 * env(tb, 0.03, 1.10, 0.2, 0.3)
	if pl > 0 then cv:LightPool(ps + pn * 0.25, pl) end
end

local BOND_BLESS = { seal = false }
local BOND_TRAIL = { w = lw(1) * 1.6 }
local BOND_WAKE = { n = 8, seed = 41, level = 0.95, size = 0.11, life = 0.55, t0 = B_B0, t1 = B_B1, drift = UP * 0.3 }
local FL_ENTRY = { size = 1.15, level = 1 }
local FL_HALO = { size = 0.7, level = 1, shock = false }
local TRAIL = {}

local function drawBless(st, cv, ts, tb, c)
	local F, S, sc = st.F, st.S, st.dsc
	blessState(st, tb, S)
	castParts(st, cv, tb, c)
	-- the Bond
	cv:Tag("bond")
	local src, dst
	if c and not st.Self then
		src, dst = bondEnds(st, c, tb)
		local u = S.bond
		if u > 0 then
			st.bsrc, st.bD = src, dst - src
			Devil.Bond(cv, sc, src, dst, u, S.lvBond, BOND_BLESS)
			if u < 1 then
				cv:Trail(RD.trail_fn(st.leadFn, tb, 0.11, 8, B_B0, TRAIL), 1.0, BOND_TRAIL)
				cv:Glint(src + st.bD * u, 0.28, 1.0, 3 * tb, nil, 0.45)
			end
			cv:Sparkles(st.leadFn, 0.2, tb, BOND_WAKE)
		end
	end
	-- the Seraph Seal
	cv:Tag("shield")
	F.turn = S_TURN * ts
	local W0 = st.T_W0
	if tb > W0 - 0.03 and tb < W0 + 0.5 then
		local entry
		if src then entry = cylEntry(F, src, dst) else entry = X(F, gc(F) + ringDir(st.PHI) * S_GR) end
		cv:Flare(entry, (tb - W0 + 0.02) / 0.5, Devil.Flare(FL_ENTRY, sc))
	end
	girdle(cv, F, S.lvG, st.PHI, S.wrap, true, tb, sc)
	ground(cv, F, S.ground, S.lvF, sc)
	arches(cv, F, S.lvA, S.arch, true, tb, sc)
	clasps(cv, F, S.clasp, S.lvC, nil, sc)
	if not st.pre then
		for k = 0, S_NCLASP - 1 do
			local tk = st.T_CLASP + 0.05 * k
			local g = 0.32 * env(tb, tk, tk + 0.4, 0.06, 0.3)
			if g > 1e-3 then
				local p, _, e = claspAt(F, k)
				cv:Glint(p + e * 0.28, g, 1.0, 0.3 + tb, nil, 0.45)
			end
		end
	end
	halo(cv, F, S.halo, S.lvH, ts, 0.7, sc)
	if not st.pre then cv:Flare(topPt(F), (tb - st.T_HALO + 0.02) / 0.45, FL_HALO) end
	rays(cv, F, S.rays, S.lvR, ts, 0, 1.9)
	glitter(cv, F, ts, st.glitterT0, nil)
	sealLight(cv, F, S.light)
	return true
end

local BOND_STEADY = { seal = false }
local BOND_REEL = { ph = 0, src_sigil = false, seal = false, pulse = true }
local FL_PAY = { size = 1.3, level = 1 }
local FL_CLASP = { size = 0.55, level = 1, shock = false }
local FL_HEAL = { size = 1.25, level = 1 }
local SUNO = { spokes = 8, s_in = 1.27, s_out = 1.77, u = 1, grow = true }
local HEAL_RAYS = { n = 12, r0 = 0.75, length = 1.5, width = 0.18, level = 1, seed = 9, v = 0, t = 0 }
local HEAL_SPARK = { n = 10, seed = 51, level = 1, size = 0.13, life = 0.7, t0 = O_TIN, t1 = O_TIN + 0.35, drift = UP * 0.9 }
local HEAL_MOTES = { n = 8, seed = 53, level = 0.9, size = 0.055, rise = 1.6, life = 0.85, t0 = O_TIN, t1 = O_TIN + 0.3,
	height = 1.5 }
local MP, MS, MT = {}, {}, {}
local MOTE_O = { size = 0.075, sizes = MS, trails = MT, trail_len = 0.4, as_particles = true }
local OUS, OLOS = { 0, 0, 0 }, { 0, 0, 0 }

--- the Overflow seal state at clip time tt: collapsing toward the chest front, spinning in
local function overflowAt(st, Fx, tt, KF)
	local col = ramp(tt, O_COL0, O_COLD)
	Fx.s = 1 - (1 - O_SEND) * col
	Fx.pivot = KF
	Fx.turn = S_TURN * (st.tsEnd + tt - Config.OverflowFrom) + 140 * col
end

local function lvl(name, to)
	local b = STEADY[name]
	return b + (PAYOFF[name] - b) * ramp(to, O_TB, 0.1)
end

--- rings -> dashes (duty shrinking), each dash a mote into the chest at its TC (overflow_light_r2._dashes)
local function overflowDashes(st, cv, F, to, duty, K, KF)
	if st.dsc and Devil.F.Drawn(Devil.F.HornDome, st.dsc, F, lvl("arches", to), 1, to, duty) then
		-- (Devil) no dashes: the horn dome crumbles to ash, tips first (frag = the duty), while the motes stream in
		-- (2026-10-19, audit P5C-02: a dome not built, or failed, gets the Default dashes below instead)
	else
		local c, r = X(F, gc(F)), S_GR * F.s
		local a0 = math.rad(F.turn)
		local lvG, lvA = lvl("girdle", to), lvl("arches", to)
		local k = 0
		for j = 0, N_GD - 1 do
			if to < TC[j + 1] then
				local hw = pi / N_GD * duty
				band(cv, arcPts(c, r, a0 + j * TAU / N_GD - hw, 2 * hw), lvG, nil, false)
				k += 1
			end
		end
		local hwI = max(1, floor(4 * duty + 0.5))
		for j = 0, N_AD - 1 do
			if to < TC[N_GD + j + 1] then
				local ci = 8 * j + 4
				local aA = pi / 2 + (ci - hwI) * TAU / 96
				local aB = pi / 2 + (ci + hwI) * TAU / 96
				local n = 0
				for q = 0, 4 do
					local p = aurLoopPt(F, aA + (aB - aA) * q / 4)
					if p.Y > F.fy + 0.02 then
						n += 1
						PTS[n] = p
					end
				end
				if n >= 2 and band(cv, n, lvA, nil, false) then k += 1 end
			end
		end
		cv:Count(k)
	end
	-- the motes
	local Fc = st.Fc
	copyFrame(Fc, F)
	local nm = 0
	for j = 1, N_GD + N_AD do
		local tc = TC[j]
		local tau = (to - tc) / MOTE_T
		if tau >= 0 and tau < 1 then
			overflowAt(st, Fc, tc, KF)
			local p0
			if j <= N_GD then
				p0 = X(Fc, gc(Fc)) + ringDir(math.rad(Fc.turn) + (j - 1) * TAU / N_GD) * (S_GR * Fc.s)
			else
				p0 = aurLoopPt(Fc, pi / 2 + (8 * (j - N_GD - 1) + 4) * TAU / 96)
			end
			local e = tau * tau
			nm += 1
			MP[nm] = p0 + (K - p0) * e
			MS[nm] = 0.075 * (1 - 0.5 * e)
			MT[nm] = K - p0
		end
	end
	trim(MP, nm)
	trim(MS, nm)
	trim(MT, nm)
	if nm > 0 then cv:Motes(MP, 1.0, MOTE_O) end
end

local function drawOverflow(st, cv, ts, tb, c)
	local to = Config.OverflowFrom + (ts - st.tsEnd)
	if to >= O_DUR then return false end
	local F, sc = st.F, st.dsc
	local K, FWD = F.K, F.fwd
	local KF = K + FWD * 0.55
	-- the caster's staff flashes
	cv:Tag("cast")
	if c and to <= O_TB + 0.6 then
		local sl = env(to, O_TB - 0.03, O_TB + 0.55, 0.06, 0.4)
		local tip = staffCall(st, c, sl, true)
		if tip then aura(cv, tip, sl, to) end
	elseif st.staffC then
		staffRelease(st)
	end
	-- the Bond: quiet, then the pulse races down it and it is reeled INTO the ally
	cv:Tag("bond")
	if c and not st.Self then
		local SRC = RD.ReceivePoint(chestOf(c, rootOf(c)), K)
		local DST = RD.ReceivePoint(K, SRC)
		if to < O_TB then
			Devil.Bond(cv, sc, SRC, DST, 1, 0.36, BOND_STEADY)
		else
			local rl = ramp(to, O_REEL0, O_REELD)
			if rl < 0.98 then
				local a = SRC + (DST - SRC) * rl
				BOND_REEL.ph, BOND_REEL.pulse = ramp(to, O_TB, 0.18, "Linear"), to < O_TB + 0.18
				Devil.Bond(cv, sc, a, DST, 1, 0.4 + 0.55 * (1 - ramp(to, O_REEL0, 0.3)), BOND_REEL)
				if rl > 0 then cv:Glint(a, 0.22 * env(to, O_REEL0, O_REEL0 + O_REELD, 0.05, 0.1), 1.0, 3 * to) end
			end
			srcSigil(cv, SRC, unitOr(DST - SRC, UP), 1 - ramp(to, O_REEL0, 0.12), 0.4 + 0.5 * ramp(to, O_TB, 0.08), sc)
		end
	end
	-- the seal: payoff bright, clasps unlock, collapse into dashes -> motes into the chest
	cv:Tag("shield")
	overflowAt(st, F, to, KF)
	cv:Flare(K + FWD * 0.7, (to - O_TB + 0.02) / 0.5, Devil.Flare(FL_PAY, sc))
	rays(cv, F, 1.0, lvl("rays", to), ts, ramp(to, 0.55, 0.28), 1.9 * (1 + 0.35 * env(to, O_TB, 0.8, 0.08, 0.3)))
	for k = 1, S_NCLASP do
		OLOS[k] = ramp(to, O_TCL[k], 0.08)
		OUS[k] = 1 - ramp(to, O_TCL[k] + 0.08, 0.1)
	end
	clasps(cv, F, OUS, lvl("clasps", to), OLOS, sc)
	for k = 0, S_NCLASP - 1 do
		local u = (to - O_TCL[k + 1] - 0.06) / 0.4
		if u > 0 and u < 1 then
			local p, _, e = claspAt(F, k)
			cv:Flare(p + e * 0.15, u, FL_CLASP)
		end
	end
	if to < O_DASH0 then
		girdle(cv, F, lvl("girdle", to), 0, 1, false, to, sc)
		arches(cv, F, lvl("arches", to), 1, false, to, sc)
	else
		overflowDashes(st, cv, F, to, 1 - 0.8 * ramp(to, O_DASH0, O_DASHD), K, KF)
	end
	halo(cv, F, 1 - ramp(to, 0.86, 0.14), lvl("halo", to), ts, 0, sc)
	ground(cv, F, 1 - ramp(to, 0.58, 0.35), lvl("ground", to), sc)
	glitter(cv, F, ts, st.glitterT0, st.tsEnd + (0.66 - Config.OverflowFrom))
	sealLight(cv, F, 0.4 * (1 - ramp(to, 0.55, 0.45)))
	-- the heal lands
	cv:Tag("heal")
	cv:Flare(K + FWD * 0.75, (to - O_TIN + 0.01) / 0.55, Devil.Flare(FL_HEAL, sc))
	local hl = env(to, O_TIN - 0.05, O_TIN + 0.75, 0.08, 0.55)
	if hl > 0 then cv:LightPool(Vector3.new(F.x, F.fy + 1.3, F.z) + FWD * 1.5, hl) end
	local g = ramp(to, O_TIN - 0.02, 0.1, "Back")
	local sk = ramp(to, O_TIN + 0.14, 0.3)
	if sc then
		-- (Devil) the sun rosette -> a solid carved chest-brand plate: it flares as the heal lands, cools, stays on
		if g > 0 then Devil.F.ChestBrand(sc, K + FWD * 0.5, FWD, g, to, O_TIN) end
	elseif g > 0 and sk < 1 then
		SUNO.u = g * (1 - 0.7 * sk)
		cv:Rosette(K + FWD * (0.55 - 0.6 * sk), FWD, 0.26, 1.0, SUNO)
	end
	HEAL_RAYS.v, HEAL_RAYS.t = ramp(to, O_TIN + 0.22, 0.3), to
	cv:HolyRays(K - unitOr(camPos - K, FWD0) * 0.35, ramp(to, O_TIN - 0.01, 0.2, "Linear"), HEAL_RAYS)
	cv:Sparkles(K, 1.0, to, HEAL_SPARK)
	cv:MoteField(Vector3.new(F.x, F.fy + 0.3, F.z), 1.3, to, HEAL_MOTES)
	return true
end

local BOND_EMPTY = { seal = false, src_sigil = false }
local EUS = { 0, 0, 0 }

local function drawEmptied(st, cv, ts, tb, c)
	local te = ts - st.tsEnd
	if te >= E_DUR and tb >= 1.2 then return false end
	local F, bp, sc = st.F, st.bp, st.dsc
	castParts(st, cv, tb, c)                         -- the caster's own cast keeps its schedule
	-- the Bond withdraws to the caster
	cv:Tag("bond")
	if c and not st.Self and bp.bond > 0 then
		local src, dst = bondEnds(st, c, st.tbEnd)
		local f = min(bp.bond, 1 - ramp(te, 0.55, 0.3))
		if f > 0.02 then Devil.Bond(cv, sc, src, src + (dst - src) * f, 1, bp.lvBond, BOND_EMPTY) end
		srcSigil(cv, src, unitOr(dst - src, UP), 1 - ramp(te, 0.78, 0.1), bp.lvBond, sc)
	end
	-- the seal comes apart quietly (never past what the blessing had drawn when it ended; Devil: the dome sinks back
	-- into the floor, the plate shrinks)
	cv:Tag("shield")
	F.turn = S_TURN * ts
	for k = 1, S_NCLASP do EUS[k] = min(bp.clasp[k], 1 - ramp(te, 0.05 + 0.06 * (k - 1), 0.16)) end
	clasps(cv, F, EUS, bp.lvC, nil, sc)
	rays(cv, F, bp.rays, bp.lvR, ts, ramp(te, 0.05, 0.3), 1.9)
	halo(cv, F, min(bp.halo, 1 - ramp(te, 0.12, 0.28)), bp.lvH, ts, 0.6, sc)
	arches(cv, F, bp.lvA, min(bp.arch, 1 - ramp(te, 0.15, 0.35)), false, ts, sc)
	girdle(cv, F, bp.lvG, st.PHI, min(bp.wrap, 1 - ramp(te, 0.30, 0.32)), false, ts, sc)
	ground(cv, F, min(bp.ground, 1 - ramp(te, 0.35, 0.3)), bp.lvF, sc)
	glitter(cv, F, ts, st.glitterT0, st.tsEnd + 0.05)
	sealLight(cv, F, bp.light * (1 - ramp(te, 0, 0.55)))
	return true
end

--- blessing -> "overflow" | "emptied", frozen at this frame
local function endPhase(st, which)
	if st.phase ~= "bless" then return end
	st.tsEnd = st.clock()
	st.tbEnd = st.tsEnd - st.castOff
	blessState(st, st.tbEnd, st.S)
	copyState(st.bp, st.S)
	st.phase = which
	if shields[st.Target] == st then shields[st.Target] = nil end
end

--- the Blessed status on the recipient (StatusEffects publishes RX_Blessed; polled, so no connection to manage)
local function watchStatus(st)
	local ok, flag = pcall(st.Target.GetAttribute, st.Target, "RX_Blessed")
	flag = ok and flag == true
	local now = os.clock()
	if flag then
		st.seen, st.offAt = true, nil
		return
	end
	if not st.seen and now - st.born < Config.FlagWait then return end
	st.offAt = st.offAt or now
	if now - st.offAt >= Config.StatusGrace then endPhase(st, "emptied") end
end

local function shieldFrame(st, cv, ts)
	camRead()
	if not sealRead(st.F, st.Target) then return false end    -- the recipient is gone
	local c = st.Caster
	if c and not rootOf(c) then c = nil end
	local tb = ts - st.castOff
	if st.phase == "bless" then watchStatus(st) end
	local sc = st.dsc
	if sc then sc:Begin(cv) end                       -- (Devil) the forms drawn this frame; the rest hide at End
	local keep
	if st.phase == "bless" then
		keep = drawBless(st, cv, ts, tb, c)
	elseif st.phase == "overflow" then
		keep = drawOverflow(st, cv, ts, tb, c)
	else
		keep = drawEmptied(st, cv, ts, tb, c)
	end
	if sc then sc:End() end
	return keep
end

local function newShield(target, caster, T0, phase)
	local scale = RD.TimeScale()
	local st = {
		Target = target, Caster = caster, Self = (caster == target),
		sealT0 = T0, castOff = 0, scale = scale, pre = false, phase = phase,
		F = newFrame(), Fc = newFrame(), S = newState(), bp = newState(),
		born = os.clock(), seen = false, offAt = nil, tsEnd = 0, tbEnd = 0,
		bsrc = Vector3.new(0, 0, 0), bD = Vector3.new(0, 0, 0),
	}
	st.clock = function()
		return (RD.ServerNow() - st.sealT0) * st.scale
	end
	st.leadFn = function(tt)
		return st.bsrc + st.bD * clamp((tt - B_B0) / (B_B1 - B_B0), 0, 1)
	end
	camRead()
	if not sealRead(st.F, target) then return nil end
	landing(st)
	st.glitterT0 = st.T_W0 + 0.15
	if phase ~= "bless" then
		st.phase = "bless"
		endPhase(st, phase)
	else
		shields[target] = st
	end
	st.h = RD.Play("RadiantBlessing", function(cv, t)
		return shieldFrame(st, cv, t)
	end, {
		Clock = st.clock,
		MaxLife = Config.BlessMaxLife,
		Owner = caster,                                  -- (2026-10-19, audit P5F-05) thinned as an enemy's by RadiantDraw
		OnEnd = function()
			live[st] = nil
			staffRelease(st)
			if st.dsc then
				st.dsc:Destroy()                         -- (Devil) the forms hidden, their meshes pooled
				st.dsc = nil
			end
			if shields[st.Target] == st then shields[st.Target] = nil end
		end,
	})
	-- THE GATE: the canvas took the caster's Blessing palette (WithPalette); Devil -> a forge scope, else nil
	st.dsc = Devil.Scope(st.h.Canvas, "RadiantBlessing", phase == "bless" and Devil.BlessWarm or Devil.OverflowWarm)
	live[st] = true
	return st
end

function Hand.Blessing(d)
	if type(d) ~= "table" then return end
	local tgt, c = d.Target, d.Character
	if not rootOf(tgt) then return end
	if typeof(c) ~= "Instance" then c = nil end
	local T0 = (type(d.T0) == "number") and d.T0 or RD.ServerNow()
	local st = shields[tgt]
	if st and st.phase == "bless" and st.h and not st.h.Dead then
		-- a refresh: the seal stays up (its clock too) and the new cast lands on it
		st.Caster, st.Self = c, (c == tgt)
		st.castOff = (T0 - st.sealT0) * st.scale
		st.pre = true
		camRead()
		if sealRead(st.F, tgt) then landing(st) end
		st.offAt = nil
		return st
	end
	return newShield(tgt, c, T0, "bless")
end

function Hand.Overflow(d)
	if type(d) ~= "table" then return end
	local tgt = d.Character
	if not rootOf(tgt) then return end
	local st = shields[tgt]
	if st and st.phase == "bless" and st.h and not st.h.Dead then
		endPhase(st, "overflow")
		return st
	end
	-- no seal on this client: the payoff from a full one (clip 3 s into a blessing: everything assembled)
	local caster = nil
	if type(d.Caster) == "number" then
		local p = Players:GetPlayerByUserId(d.Caster)
		caster = p and p.Character or nil
	end
	return newShield(tgt, caster, RD.ServerNow() - 3 / RD.TimeScale(), "overflow")
end

----------------------------------------------------------------------------------------------------
-- POSITION TRADE
----------------------------------------------------------------------------------------------------
local trades = setmetatable({}, { __mode = "k" })   -- [caster model] = its trade

-- Position Trade's helpers live in their own function: Studio's compiler refused this chunk past 200 locals
-- ("Out of local registers", Phase 5 integration). It runs once, here; Hand.TradeOut / TradeIn are defined inside.
-- (2026-10-19, audit P5C-19) THE MAIN CHUNK HOLDS 192 OF LUAU'S 200 LOCALS. Add nothing new at file scope: a further
-- skin's helpers go in the existing `Devil` table (or a sibling `Hand.Skins[name]` table), a new piece's in a function
-- like this one.
local function tradeHelpers()
--- the kit's burst: n glints fly out of p (ease-out Quint), turning and shrinking out over life (hash-seeded)
local function burst(cv, p, t, t0, n, seed, dist, life, size, level)
	local u = (t - t0) / life
	if u <= 0 or u >= 1 then return end
	for i = 0, n - 1 do
		local function gauss(k)
			local u1 = max(RD.Rand(seed, i, k), 1e-7)
			return sqrt(-2 * math.log(u1)) * cos(TAU * RD.Rand(seed, i, k + 10))
		end
		local d = unitOr(RD.B(gauss(1), gauss(2), gauss(3) * 0.7 + 0.25), UP)
		local k = 0.55 + 0.45 * RD.Rand(seed, i, 4)
		local dl = 0.15 * RD.Rand(seed, i, 5)
		local uu = clamp((u - dl) / (1 - dl), 0, 1)
		if uu > 0 then
			local q = p + d * (dist * k * ease("Quint", uu)) - UP * (0.2 * uu * uu)
			local sz = size * (0.6 + 0.4 * RD.Rand(seed, i, 6)) * sin(pi * min(1, uu * 1.15 + 0.05)) ^ 0.6
			cv:Glint(q, sz, level, RD.Rand(seed, i, 7) * 1.5 + 2 * uu, nil, (i % 3 == 0) and 0.45 or 0)
		end
	end
end

--- the lantern cage (position_trade_r2.cage) round floor point c0: u draws it on, s squeezes it sideways, dis
--- dissolves it upward
local function cage(cv, c0, s, level, u, dis)
	u, dis = u or 1, dis or 0
	if u <= 0 or s <= 0.02 or dis >= 1 then return end
	local whole = u >= 1 and dis <= 0
	local k = 0
	for i = 1, #CAGE do
		local z, r = CAGE[i][1], CAGE[i][2]
		local ru = ramp(u, 0.12 * (i - 1), 0.55)
		local rs = 1 - ramp(dis, 0.1 * (i - 1), 0.5)
		if ru > 0 and rs > 0.02 then
			local c, rr = c0 + UP * z, r * s * rs
			if ru >= 1 then
				loopBand(cv, c, rr, level, nil)
			else
				band(cv, arcPts(c, rr, pi / 6, TAU * ru), level, nil, true)
			end
			k += arcPieces(TAU * ru)
		end
	end
	local ru = ramp(u, 0.25, 0.75)
	local rr = 1 - ramp(dis, 0.15, 0.7)
	if ru > 0 and rr > 0 then
		for j = 0, 5 do
			local e = ringDir(j * pi / 3 + pi / 6)
			if ru >= 1 and rr >= 1 then
				-- whole: the 5 knots ARE the kit's Catmull-Rom (the same curve)
				for i = 1, #CAGE do PTS[i] = c0 + UP * CAGE[i][1] + e * (CAGE[i][2] * s) end
				PTS[#CAGE + 1] = c0 + UP * APEX
				band(cv, #CAGE + 1, level, nil, false)
			else
				-- drawing on (from the floor) or retracting (to the apex): the curve sampled, cut by length
				local n = 0
				local rev = rr < 1
				for q = 0, 8 do
					local f = (rev and (8 - q) or q) / 8 * 4             -- 0..4 along the 5 knots
					local i0 = min(floor(f), 3)
					local w = f - i0
					local function P(ii)
						ii = clamp(ii, 0, 4)
						if ii == 4 then return c0 + UP * APEX end
						return c0 + UP * CAGE[ii + 1][1] + e * (CAGE[ii + 1][2] * s)
					end
					local p0, p1, p2, p3 = P(i0 - 1), P(i0), P(i0 + 1), P(i0 + 2)
					local w2, w3 = w * w, w * w * w
					n += 1
					FINE[n] = (p1 * 2 + (p2 - p0) * w + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * w2 + (p1 * 3 - p0 - p2 * 3 + p3) * w3) * 0.5
				end
				-- keep the first fraction (by length)
				local frac = rev and rr or ru
				local tot = 0
				for q = 2, n do tot += (FINE[q] - FINE[q - 1]).Magnitude end
				local goal, acc, m = tot * frac, 0, 1
				PTS[1] = FINE[1]
				for q = 2, n do
					local l = (FINE[q] - FINE[q - 1]).Magnitude
					if acc + l >= goal then
						m += 1
						PTS[m] = FINE[q - 1] + (FINE[q] - FINE[q - 1]) * ((goal - acc) / max(l, 1e-9))
						break
					end
					acc += l
					m += 1
					PTS[m] = FINE[q]
				end
				band(cv, m, level, nil, true)
			end
			k += 2
		end
	end
	cv:Count(whole and 1 or k)
end

local AXIS_PTS = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 0) }
local AXIS_O = { w = lw(1) * 1.15, taper = { 0, 0 }, lo = { 0.2, 0.2 } }
local function axisLine(cv, c0, frac, level)
	if frac <= 0.02 then return end
	local mid, half = APEX / 2, APEX / 2 * frac
	AXIS_PTS[1], AXIS_PTS[2] = c0 + UP * (mid - half), c0 + UP * (mid + half)
	AXIS_O.taper[1], AXIS_O.taper[2] = 0.35 * frac, 0.35 * frac
	cv:Stroke(AXIS_PTS, level, AXIS_O)
end

local function tradeGlow(t)
	if t < P_R1 then return max(0.3 * ramp(t, 0.10, 0.12), ramp(t, P_D0 - 0.05, 0.05)) end
	return 1 - ramp(t, P_R1, 0.22)
end

local function tradeStaff(t)
	if t < P_R1 then return ramp(t, 0.02, 0.2) end
	return 0.6 * (1 - ramp(t, P_R1, 0.35))
end

--- hide both bodies (binary, client-only LocalTransparencyModifier, as UmbraFX's veil); restoring writes 0 (the first
--- person controller re-hides its own body next frame)
local function veil(st, on)
	if st.hidden == on then return end
	st.hidden = on
	if on then
		table.clear(st.veiled)
		for _, m in ipairs(st.models) do
			if m.Parent then
				for _, x in ipairs(m:GetDescendants()) do
					if x:IsA("BasePart") or x:IsA("Decal") or x:IsA("Texture") then
						x.LocalTransparencyModifier = 1
						table.insert(st.veiled, x)
					end
				end
			end
		end
	else
		for _, x in ipairs(st.veiled) do
			if x.Parent then x.LocalTransparencyModifier = 0 end
		end
		table.clear(st.veiled)
	end
end

--- the gold body flash: a Highlight per body (fill only), FillTransparency 1 - 0.8 level^1.2. Devil (devil_look
--- body_glow): the bodies TINT toward dark crimson instead -- Config.DevilTint at 1 - 0.7 level^1.2 (a Highlight's fill
--- is alpha-blended, never added light: added red over a pale body reads pink)
--- the devil's dark crimson tint, or (nil) the normal glow -- also under a WRAP worn over the skin, which draws as
--- normal Radiant does (owner, 2026-10-14)
local function devilTint(st)
	if not st.dsc then return false end
	local pal = st.h and st.h.Canvas and st.h.Canvas.Palette
	return not (type(pal) == "table" and pal.Wrap)
end

local function bodyGlow(st, i, level)
	local h = st.hl[i]
	if level <= 0.001 then
		if h and h.Enabled then h.Enabled = false end
		return
	end
	local m = st.models[i]
	if not (m and m.Parent) then return end
	if not h then
		h = Instance.new("Highlight")
		h.Name = "RadiantTradeGlow"
		local lpal = st.h and st.h.Canvas and st.h.Canvas.Palette        -- (2026-10-25: a ladder wrap's BodyGlow)
		local bg = lpal and lpal.Look and lpal.Look.BodyGlow
		h.FillColor = devilTint(st) and Config.DevilTint or bg or Config.GlowColor
		h.OutlineTransparency = 1
		h.FillTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded       -- never through walls
		h.Adornee = m
		h.Parent = fxFolder()
		st.hl[i] = h
		st.hlFT[i] = 1
	end
	-- (2026-10-19, audit P5C-07) Reduce Flashing: the body flash at half its level (FillTransparency 0.2 -> ~0.65)
	local cvs = st.h and st.h.Canvas
	if cvs and cvs.Calm then level *= 0.5 end
	local clk = cvs and cvs.Palette and cvs.Palette.Look
	if clk and clk.Cycle and not devilTint(st) then          -- (2026-10-25) Prism Bloom: the body flash runs the cycle
		local x = (2 * (cvs.LookPH or 0)) % 2
		local c = cvs.Palette.At(x <= 1 and x or 2 - x)
		if h.FillColor ~= c then h.FillColor = c end
	end
	local ft = 1 - (devilTint(st) and Config.DevilTintMax or Config.HighlightMax) * level ^ 1.2
	if abs(st.hlFT[i] - ft) > 0.004 then
		st.hlFT[i] = ft
		h.FillTransparency = ft
	end
	if not h.Enabled then h.Enabled = true end
end

local function tradeEnd(st)
	veil(st, false)
	for i, h in pairs(st.hl) do
		h:Destroy()                                            -- our own runtime Highlight
		st.hl[i] = nil
	end
	staffRelease(st)
	if st.dsc then
		st.dsc:Destroy()                                       -- (Devil) the maws hidden, their meshes pooled
		st.dsc = nil
	end
	live[st] = nil
	if trades[st.C] == st then trades[st.C] = nil end
end

local function spotLive(sp, m)
	local r = rootOf(m)
	if r then sp.p = r.Position end
end

local GT_TIP = { radius = 0.8, n = 6, level = 0.95, glint_size = 0, seed = 7, t = 0 }
local GT_BODY = { radius = 1.6, n = 8, level = 0.95, glint_size = 0.35, seed = 11, t = 0 }
local FL_OUT = { size = 1.25, level = 1 }
local FL_IN = { size = 1.15, level = 1 }
local TR_SPARK = { n = 6, seed = 12, level = 0.9, size = 0.11, life = 0.6, t0 = P_R1, t1 = P_R1 + 0.25, drift = UP * 0.5 }
local BR_BOND = { src_sigil = false, seal = false, pulse = false }
local BR_TRAIL = { w = lw(1) * 1.7 }
local BR_TRAIL2 = { w = lw(1) * 1.5 }
local BR_WAKE = { n = 10, seed = 41, level = 0.95, size = 0.12, life = 0.5, t0 = P_BR0, t1 = P_BR0 + P_BRD,
	drift = UP * 0.35 }
local TRAIL2 = {}

--- one spot's glow gathering on the body, its lantern cage, the axis line and the apex glint
local function cageSpot(cv, c0, t)
	if t < P_D0 + P_FLASH then
		GT_BODY.t = t
		cv:Gather(c0 + UP * 3.3, ramp(t, 0.06, 0.18), GT_BODY)
	end
	if t < P_D0 then
		cage(cv, c0, 1, 0.45 + 0.2 * ramp(t, P_D0 - 0.03, 0.04), ramp(t, 0.10, 0.13, "Linear"), 0)
	elseif t < P_SWAP then
		cage(cv, c0, 1 - ramp(t, P_D0, P_SWAP - P_D0), 0.6, 1, 0)
		axisLine(cv, c0, ramp(t, P_D0, 0.05), 1.0)
	elseif t < P_R1 + 0.03 then
		cage(cv, c0, ramp(t, P_SWAP, P_R1 - P_SWAP), 0.6, 1, 0)
		axisLine(cv, c0, 1 - ramp(t, P_SWAP + 0.02, P_R1 - P_SWAP - 0.02), 1.0)
	else
		cage(cv, c0, 1, 0.6 - 0.2 * ramp(t, P_R1, 0.2), 1, ramp(t, P_DIS0, P_DISD))
		local g = 0.34 * env(t, P_DIS0 + 0.15, P_DIS0 + P_DISD + 0.25, 0.08, 0.2)
		if g > 1e-3 then cv:Glint(c0 + UP * (APEX + 0.05), g, 1.0, 2 * t, nil, 0.45) end
	end
end

local function tradeFrame(st, cv, t)
	if st.lost or t >= P_DUR then return false end
	camRead()
	local sc = st.dsc
	if sc then sc:Begin(cv) end                           -- (Devil) the forms drawn this frame; the rest hide at End
	local s1, s2 = st.spots[1], st.spots[2]
	-- the two world spots (the demo's CA / EA): each body's live root until the swap, then the server's B / A
	if t < P_SWAP or st.cancel then
		spotLive(s1, st.C)
		spotLive(s2, st.O)
	else
		s1.p = st.B or s1.p
		s2.p = st.A or s2.p
	end
	local vis = t < P_D0 + P_FLASH or t >= P_R1
	veil(st, not vis)
	local gl = vis and tradeGlow(t) or 0
	bodyGlow(st, 1, gl)
	bodyGlow(st, 2, gl)
	-- the caster's staff: gathers and brightens, hidden with the body, back at 0.6
	cv:Tag("cast")
	local sl = vis and tradeStaff(t) or 0
	local tip = staffCall(st, st.C, sl, vis)
	if vis and tip then
		aura(cv, tip, sl, t)
		if t < P_D0 + P_FLASH then
			GT_TIP.t = t
			cv:Gather(tip, ramp(t, 0, 0.2), GT_TIP)
		end
	end
	-- glow gathers on both bodies, the cages, the flashes, the lines
	cv:Tag("cage")
	local swapped = t >= P_SWAP and not st.cancel
	for i = 1, 2 do
		local sp = st.spots[i].p
		local c0 = Vector3.new(sp.X, sp.Y - Config.RootHeight, sp.Z)
		if sc then
			-- (Devil) the gather, the cage, the axis line and the apex glint -> a fanged maw + four claws (the clip's own
			-- schedule: rise, close at the flash, sink, rise at the swapped spot, release); embers boil from it. Its id
			-- is the PLACE (a spot follows its body, so it changes place at the swap). (2026-10-19, audit P5C-02) a maw
			-- not built yet, or failed, gets the Default cage instead
			if not Devil.F.Drawn(Devil.F.Maw, sc, swapped and (3 - i) or i, c0, t) then cageSpot(cv, c0, t) end
		else
			cageSpot(cv, c0, t)
		end
		cv:Flare(c0 + UP * 3.3, (t - P_D0 + 0.015) / 0.32, Devil.Flare(FL_OUT, sc))
		cv:Flare(c0 + UP * 3.3, (t - P_R1 + 0.01) / 0.32, Devil.Flare(FL_IN, sc))
		burst(cv, c0 + UP * 3.2, t, P_R1 - 0.01, 12, BURST_SEED[i], 1.9, 0.55, 0.15, 1.0)
		TR_SPARK.seed = SPARK_SEED[i]
		cv:Sparkles(c0 + UP * 2.8, 1.3, t, TR_SPARK)
		local ll = 0.55 * env(t, 0.08, P_R1 + 0.55, 0.14, 0.45) + 0.6 * env(t, P_D0 - 0.04, P_D0 + 0.2, 0.04, 0.14)
			+ 0.6 * env(t, P_R1 - 0.02, P_R1 + 0.3, 0.03, 0.25)
		if ll > 0 then cv:LightPool(c0 + UP * 2.4 + unitOr(hor(camPos - c0), FWD0) * 1.4, ll) end
	end
	-- the golden bridge: caster's spot -> the other's, retracting into the caster's new spot
	cv:Tag("bond")
	local a = Vector3.new(s1.p.X, s1.p.Y - Config.RootHeight + BRIDGE_Z, s1.p.Z)
	local b = Vector3.new(s2.p.X, s2.p.Y - Config.RootHeight + BRIDGE_Z, s2.p.Z)
	local D = b - a
	local dd = unitOr(D, FWD0)
	st.ba, st.bD = a, D
	local u = ramp(t, P_BR0, P_BRD, "Linear")
	local rt = ramp(t, P_RT0, P_RTD)
	if u > 0 and rt < 0.98 then
		local tail, lead
		if st.cancel then
			tail, lead = a, a + D * (u * (1 - rt))             -- cancelled: it pulls back into the caster
		else
			tail, lead = a + D * rt, a + D * u
		end
		Devil.Bond(cv, sc, tail, lead, 1.0, 0.9, BR_BOND)     -- (Devil) a taut barbed contract line (pulse false)
		if u < 1 then
			cv:Trail(RD.trail_fn(st.leadFn, t, 0.05, 8, P_BR0, TRAIL), 1.0, BR_TRAIL)
			cv:Glint(lead, 0.34, 1.0, 3 * t, nil, 0.45)
		end
		if rt > 0 then
			if not st.cancel then
				cv:Trail(RD.trail_fn(st.tailFn, t, 0.04, 6, P_RT0, TRAIL2), 1.0, BR_TRAIL2)
				cv:Glint(tail, 0.26, 1.0, 2 * t, nil, 0)
			else
				cv:Glint(lead, 0.26, 1.0, 2 * t, nil, 0)
			end
		end
	end
	cv:Sparkles(st.leadFn, 0.25, t, BR_WAKE)
	srcSigil(cv, a, dd, ramp(t, P_D0, 0.03) * (1 - ramp(t, P_RT0, 0.04)), 1.0, sc)
	drawSeal(cv, b, dd, ramp(t, P_BR0 + P_BRD - 0.01, 0.03) * (1 - ramp(t, P_RT0 + P_RTD - 0.03, 0.03)), 1.0, sc)
	if sc then sc:End() end
	return true
end

function Hand.TradeOut(d)
	if type(d) ~= "table" then return end
	local c, o = d.Character, d.Other
	if typeof(c) ~= "Instance" or typeof(o) ~= "Instance" then return end
	local old = trades[c]
	if old and old.h then old.h:Stop() end
	local scale = RD.TimeScale()
	local dis = (type(d.Dissolve) == "number" and d.Dissolve > 0) and d.Dissolve or (0.12 / scale)
	local st = {
		C = c, O = o, models = { c, o }, rOut = os.clock(), rIn = nil, dis = dis,
		k1 = (P_SWAP - Config.TradeClipAtOut) / dis, k2 = scale,
		spots = { { p = typeof(d.From) == "Vector3" and d.From or Vector3.new(0, 0, 0) },
			{ p = typeof(d.To) == "Vector3" and d.To or Vector3.new(0, 0, 0) } },
		hidden = false, veiled = {}, hl = {}, hlFT = {}, lost = false, cancel = false,
		ba = Vector3.new(0, 0, 0), bD = Vector3.new(0, 0, 0),
	}
	spotLive(st.spots[1], c)
	spotLive(st.spots[2], o)
	st.clock = function()
		local now = os.clock()
		if st.rIn then return P_SWAP + (now - st.rIn) * st.k2 end
		local t = Config.TradeClipAtOut + (now - st.rOut) * st.k1
		if t > P_SWAP - 1e-3 then
			t = P_SWAP - 1e-3                                  -- the lines hold until the swap is heard
			if now - st.rOut > st.dis + Config.TradeInWait then st.lost = true end
		end
		return t
	end
	st.leadFn = function(tt)
		return st.ba + st.bD * ramp(tt, P_BR0, P_BRD, "Linear")
	end
	st.tailFn = function(tt)
		return st.ba + st.bD * ramp(tt, P_RT0, P_RTD)
	end
	trades[c] = st
	live[st] = true
	st.h = RD.Play("RadiantTrade", function(cv, t)
		return tradeFrame(st, cv, t)
	end, { Clock = st.clock, MaxLife = 6, Owner = c, OnEnd = function() tradeEnd(st) end })   -- Owner: audit P5F-05
	-- THE GATE: the canvas took the caster's Position Trade palette (WithPalette); Devil -> a forge scope, else nil
	st.dsc = Devil.Scope(st.h.Canvas, "RadiantTrade", Devil.TradeWarm)
	return st
end

function Hand.TradeIn(d)
	if type(d) ~= "table" then return end
	local st = trades[d.Character]
	if not st or st.rIn then return end
	st.rIn = os.clock()
	if d.Cancelled then
		st.cancel = true
	else
		st.A = (typeof(d.A) == "Vector3") and d.A or nil
		st.B = (typeof(d.B) == "Vector3") and d.B or nil
	end
end
end
tradeHelpers()

----------------------------------------------------------------------------------------------------
Hand.Handlers = {
	RadiantBlessing = Hand.Blessing,
	RadiantOverflow = Hand.Overflow,
	RadiantTradeOut = Hand.TradeOut,
	RadiantTradeIn = Hand.TradeIn,
}

function Hand.StopAll()
	for st in pairs(live) do
		if st.h then st.h:Stop() end
	end
end

--- the Devil skin's hand forms built ahead (RadiantDevilForge.PrewarmPiece, once per client), for a caller that sees
--- a Devil Blessing / Position Trade skin about; without it the first Devil effect of each kind starts the builds
function Hand.PrewarmDevil()
	local F = Devil.Forge()
	if F then Devil.Warm(F, { "Blessing", "Overflow", "Trade" }) end
end

--- diagnostics: running effects, blessing-phase shields, trades on this client
function Hand.Active()
	local n, ns, nt = 0, 0, 0
	for _ in pairs(live) do n += 1 end
	for _ in pairs(shields) do ns += 1 end
	for _ in pairs(trades) do nt += 1 end
	return n, ns, nt
end

return Hand
