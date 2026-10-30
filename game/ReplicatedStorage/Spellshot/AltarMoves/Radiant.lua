--[[
	AltarMoves_Radiant  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Radiant

	The Loadout Altar showcase's Radiant page, CONTRACT v2 (2026-10-26, the owner: the altar plays every move of the
	Element on the dais the way a duel shows it -- a caster that PERFORMS the move, a target that TAKES it -- in the wrap
	being looked at). Moves = Radiant's kit in loadout order -- Light Lance, Blessing, Position Trade, Benediction, Halo,
	Overflow Light (its M1 / Primary / Passive, Config.ElementDefaults.Radiant, its own Ultimate). Client only: no
	remotes, nothing sent, no real damage.

	THE STAGE (AltarShowcase builds it before Play; AltarStage makes the dummies): stage.Caster, a visible grey R15
	mannequin at Floor - RightVector * 7 facing +RightVector, and stage.Target at Floor + RightVector * 7 facing it, both
	under workspace.TrainingGround. Nothing here clones or hides a rig any more: the two dummies ARE the duel.

	EACH MOVE'S PLAY loops one beat (cast -> hit) until stop():
	  BODY   the game's own third-person clips on stage.Caster through the one CastPose (IceMagic.CastPose), played the
	         way RadiantAnim plays them on a Radiant body it sees (its broadcast handlers are local to it, so the calls
	         are made here): the body rests on SetBase "RadiantCarry"; RadiantLance is held and let go with Stop;
	         RadiantBlessing plays from the cast; RadiantTrade, RadiantHaloWindup and RadiantBenediction run on
	         RadiantAnim's own clocks (the press, the windup stretched to the lock, the plant held until the End); Halo's
	         two body turns are written on the R15 Root joint after CastPose, as RadiantAnim writes them. The clips are
	         RadiantPoseTable's, registered into CastPose.Clips exactly as RadiantAnim.register does (`X = X or`) when no
	         Radiant body has done it yet.
	  STAFF  (2026-10-26, the owner: the caster holds the Radiant staff, as a real Radiant does) RadiantAnim makes the
	         prop only for a PLAYER whose Element is Radiant, so the dummy cast empty-handed and every look drew from
	         RadiantFX_Staff's tip estimate. Now the preview gives the caster RadiantAnim's own staff, built and held its
	         way (THE STAFF, below: the asset, the skin's body, every clip's hold track, the plant, the engraving glow),
	         and RadiantAnim's staff reads (StaffPoint ...) answer for the dummy from it while a preview runs, so Light
	         Lance, Halo, Benediction and the hand pieces draw from its tip. Gone with stop().
	  VFX    the server's broadcasts, made up here on RadiantHandler's schedule with its payload shapes (every number
	         RadiantTuning's), handed to RadiantClient.Handlers -- the very path every other client draws a Radiant
	         caster through (RadiantFX_Staff: the lance, Halo, Benediction; RadiantFX_Hand: Blessing, Overflow, the
	         Trade). Radiant's pieces are authored on ONE clock with their clips (a broadcast's T0 is the clip's 0), so
	         each starts with its clip and its own schedule lands the release on the clip's Trigger; only Position
	         Trade's RadiantTradeOut waits for its Trigger (0.1: the staff tap comes before the broadcast).
	  WRAP   every payload carries Skin = the caster's look, as RadiantHandler stamps the caster's skin on every
	         Radiant broadcast; RadiantClient resolves it per ability (SkinCatalog.Resolve, AbilityOfKind) into
	         RadiantDraw.WithPalette. A wrap is never dropped to Default here (one that does not resolve is warned once).
	         (2026-10-26) SKIN: with stage.Skin on (the Devil; AltarStage.Look) the stamp is SkinCatalog.Chosen's --
	         "Devil+<Wrap>" for a colour wrap worn over it (WrapsOverSkin), else "Devil" -- never the bare wrap or nil,
	         which would draw the Default forms over the skin; the staff wears the same (the trident).
	  HIT    the target takes it as a duel shows it (stage.React = AltarStage):
	           Light Lance     a damage number every Tick (0.25 s) from contact, DpsStart 16 -> DpsMax 32 over RampTime
	                           2 s on the one target (4 -> 8 a tick), a recoil on first contact and at the full-ramp payoff
	           Blessing        the ally's BLESSED as the Bond lands (RX_Blessed holds the Seraph Seal up), then spent
	           Position Trade  the two bodies themselves swap (each keeps its facing), and the caster turns and trades back
	           Benediction     the ally in range takes the heal thread on every pulse: RadiantHandler's "+8" readout
	           Halo            the windup, the lock, the wings -- then a short Light Lance into the target under it: its
	                           ticks land, and each one heals the caster (HealPct 1.0, HealCap 60: the "+N" readout)
	           Overflow Light  the caster's own: a self Blessing kept whole pays out ConvertPct 0.6 of StatusEffects'
	                           Absorb (35 in preset A: "+21") -- the passive touches nobody else
	         The heal readout is RadiantHandler's Callouts style "heal" (RadiantTuning.HealPop); the server registers it
	         on ITS copy of Callouts, so the same style is registered on the client's here, once, if it is missing.

	stop() ends the loop and every look AT ONCE -- each RadiantDraw effect this preview starts is caught as it starts
	(RadiantDraw.Play wrapped for the length of the synchronous handler call, put straight back) and stopped, since a
	running Halo or Benediction keeps no stop of its own short of its caster going away; RadiantClient's lance tracker
	is told its beam is off -- puts the clips down (CastPose Stop / SetAim nil / SetBase nil), puts back what it changed
	(RX_Blessed, the Root joint, the caster's HipHeight; 2026-10-26: the staff gone, RadiantAnim's staff reads put back
	once no preview holds one) and both dummies where they stood, then stage.React.Reset.
	Safe to call twice; the stage folder going away calls it too. Nothing errors into the caller.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UP = Vector3.yAxis
local BLESSED = "RX_Blessed"           -- StatusEffects' Blessed flag: RadiantFX_Hand polls it, the seal is up while true
local HIP = 2.192                      -- the mannequin's standing HipHeight (HubLife: feet 3.192 under the root, = 2.192 +
                                       -- half the root). A Humanoid AltarStage made itself has 0, which Halo's airborne
                                       -- test reads as a body in the air (the glide), so the Halo preview stands it up
local ABSORB = { A = 35, B = 30, C = 25 }   -- StatusEffects.Presets[*].Blessed.Absorb (a server module: its numbers)
local LANCE_CONTACT = 0.27             -- clip s from the click to the beam on the body (RadiantFX_Staff: gather 0.2 + draw 0.07)

-- each move's beat, real seconds (the move's own numbers are RadiantTuning's; the beat is the showcase's)
local LANCE = { Hold = 3.0, Every = 4.3 }                    -- the 2 s ramp, ~0.7 s of the full-ramp payoff, let go
local BLESS = { Land = 0.45, Hold = 2.4, Every = 3.8 }       -- the Bond lands ~0.45 s in; the seal up 2.4 s, then spent
local TRADE = { Wait = 1.1, Turn = 0.3, Every = 4.2 }        -- trade, a beat, turn, trade back, a beat, turn home
local BENE = { Pulses = 4, Every = 4.3 }                     -- planted 0.5 s after the press, 4 heal pulses, the let-go
local HALO = { LanceAt = 0.35, LanceFor = 1.4, EndAfter = 0.2, Every = 4.5 }   -- lock 0.9, the lance, the End (~1.3 s)
local OVERFLOW = { Land = 0.44, At = 1.5, Every = 3.6 }      -- a self Blessing (seal 0.436 in), its payoff at 1.5 s (~2 s)

----------------------------------------------------------------------------------------------------
-- modules, found lazily (only ever waited for on a move's own loop thread: Play and stop() never wait)
----------------------------------------------------------------------------------------------------
local HOME = { SkinCatalog = "Spellshot", Callouts = "Spellshot", AltarStage = "Spellshot" }   -- the rest: IceMagic
local mods = {}
local warned = {}

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Radiant] " .. tostring(msg))
end

--- the module, required once (nil: not replicated yet -- asked again next cast -- or it failed). nowait: only if it is
--- already loaded (stop()'s path)
local function need(name, nowait)
	local m = mods[name]
	if m ~= nil then return m or nil end
	if nowait then return nil end
	local folder = ReplicatedStorage:WaitForChild(HOME[name] or "IceMagic", 5)
	local inst = folder and folder:WaitForChild(name, 5)
	if not inst then return nil end
	local ok, mod = pcall(require, inst)
	mods[name] = (ok and type(mod) == "table") and mod or false
	if not mods[name] then warnOnce("req:" .. name, name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

-- the display names: SpellshotConfig's (Elements.Radiant M1 / Primary / Passive, the Mobility / Defense / Ultimate rows)
local NAMES = { M1 = "Light Lance", Primary = "Blessing", Mobility = "Position Trade", Defense = "Benediction",
	Ultimate = "Halo", Passive = "Overflow Light" }
do
	local sp = ReplicatedStorage:FindFirstChild("Spellshot")
	local cm = sp and sp:FindFirstChild("SpellshotConfig")
	local ok, C = pcall(function() return cm and require(cm) end)
	if ok and type(C) == "table" then
		local function name(row) return type(row) == "table" and type(row.Name) == "string" and row.Name or nil end
		local e = type(C.Elements) == "table" and C.Elements.Radiant or nil
		e = type(e) == "table" and e or {}
		NAMES.M1 = name(e.M1) or NAMES.M1
		NAMES.Primary = name(e.Primary) or NAMES.Primary
		NAMES.Passive = name(e.Passive) or NAMES.Passive
		NAMES.Mobility = name(type(C.Mobility) == "table" and C.Mobility.PositionTrade) or NAMES.Mobility
		NAMES.Defense = name(type(C.Defense) == "table" and C.Defense.Benediction) or NAMES.Defense
		NAMES.Ultimate = name(type(C.Ultimate) == "table" and C.Ultimate.Halo) or NAMES.Ultimate
	end
end

-- which ability's palette a move draws with (the wrap check; SkinCatalog.Kinds: RadiantOverflow is Blessing's)
local ABILITY = { LightLance = "LightLance", Blessing = "Blessing", PositionTrade = "PositionTrade",
	Benediction = "Benediction", Halo = "Halo", OverflowLight = "Blessing" }

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function flat(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-4 and f.Unit or fallback
end

local function partOf(m, name)
	local p = typeof(m) == "Instance" and m:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end

local function chestOf(m, fallback)
	local p = partOf(m, "UpperTorso") or partOf(m, "Torso")
	if p then return p.Position end
	local r = partOf(m, "HumanoidRootPart")
	return r and (r.Position + UP * 0.85) or fallback
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

--- the filming slow-down (IceMagic's ShotTimeScale: VFXLibrary.ShotTimeScale, RadiantAnim's timeScale)
local function timeScale()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local v = ice and ice:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

--- RadiantAnim's clockFrom: clip seconds since `start` (os.clock), x ShotTimeScale
local function clockFrom(start)
	return function() return (os.clock() - start) * timeScale() end
end

--- where a dummy stands at rest: its AltarHome (AltarStage's), facing `dir`
local function restCF(m, dir)
	local h = m:GetAttribute("AltarHome")
	local p = typeof(h) == "Vector3" and h or m:GetPivot().Position
	return CFrame.lookAt(p, p + dir)
end

local function yawOf(v)
	return math.atan2(-v.X, -v.Z)          -- CFrame.Angles(0, yaw, 0).LookVector = (-sin yaw, 0, -cos yaw)
end

local function wrapPi(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

--- StatusEffects' Blessed Absorb under the live preset (the Spellshot folder's StatusPreset attribute)
local function absorb()
	local sp = ReplicatedStorage:FindFirstChild("Spellshot")
	local p = sp and sp:GetAttribute("StatusPreset")
	return ABSORB[p] or ABSORB.A
end

--- the wrap's palette for `ability` (nil = Default: no wrap, not a Radiant wrap, or the catalog is not there). The
--- payloads' Skin is what draws the wrap; this is the wrap check and the no-RadiantClient fallback
local function palette(ability, wrapId)
	if type(wrapId) ~= "string" or wrapId == "Default" then return nil end
	local SC = need("SkinCatalog")
	local ok, p = pcall(function() return SC and SC.Resolve("Radiant", ability, wrapId) end)
	if not ok then warnOnce("pal:" .. wrapId, "wrap " .. wrapId .. ": " .. tostring(p)) end
	return ok and p or nil
end

--- fn(...) with `pal` handed to every effect it starts (RadiantClient.skinned)
local function skinned(pal, fn, ...)
	local RD = need("RadiantDraw", true)
	if pal and RD and RD.WithPalette then return RD.WithPalette(pal, fn, ...) end
	return fn(...)
end

--- (2026-10-26) the caster's look, AltarStage.Look's one rule: Radiant's skin on it (nil = the Default kit) and the id
--- RadiantHandler stamps on its broadcasts -- SkinCatalog.Chosen's: "<Skin>+<Wrap>" for a colour wrap worn over the
--- skin, the skin alone, the wrap alone, nil for Default. Never waits (Play's path)
local function lookOf(stage)
	local R = type(stage.React) == "table" and stage.React or need("AltarStage", true)
	local skin, wrap = nil, (type(stage.Wrap) == "string" and stage.Wrap ~= "") and stage.Wrap or "Default"
	if R and type(R.Look) == "function" then
		local ok, s, w = pcall(R.Look, stage, "Radiant")
		if ok then skin, wrap = s, w end
	end
	if skin then return skin, (wrap ~= "Default") and (skin .. "+" .. wrap) or skin end
	return nil, (wrap ~= "Default") and wrap or nil
end

----------------------------------------------------------------------------------------------------
-- the body: CastPose on stage.Caster
----------------------------------------------------------------------------------------------------
local clipsIn = false

--- RadiantPoseTable's clips in CastPose.Clips: RadiantAnim.register's own `X = X or` copy (a no-op once any Radiant body
--- has been seen; the same tables when none has yet)
local function clips(CP)
	if clipsIn then return true end
	if type(CP.Clips) ~= "table" then return false end
	if not CP.Clips.RadiantCarry then
		local P = need("RadiantPoseTable")
		if not (P and type(P.Clips) == "table") then return false end
		for name, clip in pairs(P.Clips) do CP.Clips[name] = CP.Clips[name] or clip end
	end
	clipsIn = true
	return true
end

--- the caster's body clip (`clock` for a clocked one), guarded
local function pose(run, clip, clock)
	local CP = need("CastPose")
	if not (run.Alive and CP and clips(CP)) then return end
	local ok, err = pcall(clock and CP.PlayClocked or CP.Play, run.Caster, clip, clock)
	if not ok then warnOnce("pose:" .. clip, "CastPose " .. clip .. ": " .. tostring(err)) end
end

--- a HELD clip let go (the Light Lance's), if it is still the one on the body: it eases home on the clip's ReleaseRate
local function unpose(run, clip)
	local CP = need("CastPose", true)
	if CP and CP.CurrentClip(run.Caster) == clip then pcall(CP.Stop, run.Caster) end
end

--- the clip's release beat (clip seconds)
local function trigger(name, default)
	local CP = need("CastPose", true)
	local c = CP and type(CP.Clips) == "table" and CP.Clips[name]
	return (type(c) == "table" and type(c.Trigger) == "number") and c.Trigger or default
end

--- the R15 Root joint's writable slot (RadiantAnim.rootJoint)
local function rootJoint(m)
	local lt = m:FindFirstChild("LowerTorso")
	local j = lt and lt:FindFirstChild("Root")
	if j and j:IsA("AnimationConstraint") and j.Attachment0 then return j.Attachment0, "CFrame" end
	if j and j:IsA("Motor6D") then return j, "C0" end
	return nil, nil
end

local function near(a, b)
	local d = a.Position - b.Position
	if d:Dot(d) > 1e-8 then return false end
	return a.LookVector:Dot(b.LookVector) > 0.99999 and a.UpVector:Dot(b.UpVector) > 0.99999
end

--- RadiantAnim.sampleSpin: the track's yaw at clip time t, eased INTO each key (nil past the last key)
local function sampleSpin(track, t)
	if t < track[1].t then return track[1].Deg end
	if t >= track[#track].t then return nil end
	for i = 1, #track - 1 do
		local a, b = track[i], track[i + 1]
		if t <= b.t then
			local u = math.clamp((t - a.t) / math.max(1e-4, b.t - a.t), 0, 1)
			local e = TweenService:GetValue(u, b.Easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			return a.Deg + (b.Deg - a.Deg) * e
		end
	end
	return nil
end

local spinSeq = 0

--- HALO'S SPIN: the windup's two whole-body turns (RadiantPoseTable.Spin) on the Root joint, after CastPose has posed the
--- body (RadiantAnim's spinStep, at its RenderPriority Character + 2): the yaw goes on whatever the joint holds this
--- frame -- CastPose's fresh write, or (no write since ours) the base we kept -- and the joint is handed back the frame
--- the clip is over
local function spin(run, clock)
	if run.EndSpin then run.EndSpin() end
	local P, CP = need("RadiantPoseTable"), need("CastPose")
	local track = P and type(P.Spin) == "table" and P.Spin.RadiantHaloWindup
	local inst, prop = rootJoint(run.Caster)
	if not (run.Alive and type(track) == "table" and #track > 1 and inst and CP) then return end
	spinSeq += 1
	local name = "AltarRadiantSpin" .. spinSeq
	local sp = { Base = nil, Last = nil, Done = false }
	local finish, tick
	finish = function()
		if sp.Done then return end
		sp.Done = true
		if run.EndSpin == finish then run.EndSpin = nil end
		if run.SpinTick == tick then run.SpinTick = nil end
		pcall(RunService.UnbindFromRenderStep, RunService, name)
		if sp.Last and sp.Base and inst.Parent then
			local ok, cur = pcall(function() return inst[prop] end)
			if ok and near(cur, sp.Last) then pcall(function() inst[prop] = sp.Base end) end
		end
	end
	run.EndSpin = finish
	tick = function()
		local ok = pcall(function()
			if not (run.Alive and inst.Parent) then return finish() end
			local deg = sampleSpin(track, clock())
			if deg == nil or CP.CurrentClip(run.Caster) ~= "RadiantHaloWindup" then return finish() end
			local cur = inst[prop]
			local base = (sp.Last and near(cur, sp.Last)) and sp.Base or cur
			sp.Base = base
			local w = base * CFrame.Angles(0, math.rad(deg), 0)
			inst[prop] = w
			sp.Last = w
		end)
		if not ok then finish() end
	end
	if run.Held then
		run.SpinTick = tick                    -- (2026-10-26) stepped by the staff's binding, before the staff is placed
	else
		RunService:BindToRenderStep(name, Enum.RenderPriority.Character.Value + 2, tick)
	end
end

----------------------------------------------------------------------------------------------------
-- THE STAFF (2026-10-26, the owner: the caster holds the Radiant staff during its moves, as a real Radiant does)
----------------------------------------------------------------------------------------------------
-- The root cause: RadiantAnim makes the staff prop only for a PLAYER whose Element is Radiant (its refresh(plr), off the
-- Players service), and every Radiant look reads the staff tip through RadiantAnim.StaffPoint -- so the dummy cast
-- empty-handed and Light Lance, Halo and Benediction drew from RadiantFX_Staff's carry-tip estimate. RadiantAnim's prop
-- code is local to it, so the preview gives the caster the SAME staff, built and held RadiantAnim's way, line for line:
-- the asset (RadiantAnim.Config.AssetPaths: StaffA's Body + Lines at StaffGeometry's sizes and offsets), the body its
-- look gives it (the Devil trident from RadiantDevilStaffData, slid DEVIL_TP_SLIDE down through the hand; a colour
-- wrap's recoloured StaffA body), the hold each clip's staff track names (RadiantPoseTable.Staff / StaffRelease: carry,
-- press, two_hand(_f), and raise / planted / pulled at Benediction's plant), placed at RadiantAnim's RenderPriority
-- (after CastPose, before RadiantDraw samples the tip) and lit through RadiantDraw.StaffGlow on RadiantAnim's per-piece
-- rules (RadiantPoseTable.Timing). While a preview holds a staff, RadiantAnim's staff reads (StaffPoint, StaffCFrame,
-- StaffLevel, PlantPoint, SetStaffHidden -- the anchors RadiantClient hands RadiantFX_Staff and RadiantFX_Hand call
-- them through the module table) answer for the dummy from it, and are put back when the last preview stops.
-- Keep this in step with RadiantAnim's staff (newStaff / Staff:Glow / bodyFrame / holdNow / the glow sources).
local STAFF_PRIORITY = Enum.RenderPriority.Character.Value + 2       -- RadiantAnim's StepPriority
local STAFF_PATHS = { { "RadiantAssets", "StaffA" }, { "RadiantMeshes", "StaffA" }, { "IceMagicMeshes", "RadiantKit", "StaffA" } }
local DEVIL_TP_SLIDE = 0.72          -- RadiantAnim's third-person trident: slid this far down through the hand
local SMOOTH_HEAD_FROM, SMOOTH_COS = 3.1, math.cos(math.rad(65))   -- the trident's smooth-shaded head (staff studs)
local LINE_IDLE = Color3.fromRGB(185, 164, 106)
local GOLD = Color3.fromRGB(245, 194, 48)
local INLAY_HOT = Color3.fromRGB(255, 231, 160)
local WORLD = { raise = true, planted = true, pulled = true }      -- the holds stood in the floor, not the hand

local function clamp01(x)
	return x < 0 and 0 or (x > 1 and 1 or x)
end
local function ramp(t, t0, dur)
	if dur <= 0 then return t >= t0 and 1 or 0 end
	return 0.5 - 0.5 * math.cos(math.pi * clamp01((t - t0) / dur))
end
local function env(t, t0, t1, fin, fout)
	if t <= t0 or t >= t1 then return 0 end
	return math.min(ramp(t, t0, fin), 1 - ramp(t, t1 - fout, fout))
end
local STYLE = {}
local function easeOut(style, u)
	u = clamp01(u)
	if style == nil or style == "Linear" then return u end
	if style == "In1.6" then return u ^ 1.6 end
	local es = STYLE[style]
	if es == nil then
		local ok, e = pcall(function() return Enum.EasingStyle[style] end)
		es = ok and e or false
		STYLE[style] = es
	end
	if not es then return u end
	return TweenService:GetValue(u, es, Enum.EasingDirection.Out)
end

-- THE BODY UNDER A LOOK: built once per client per palette, off the render loop (RadiantAnim's own caches are local to
-- it). A colour wrap recolours StaffA's baked vertex colours along its length (RadiantAnim's skinBody); the Devil skin
-- is its trident (RadiantAnim's buildDevilPart / getDevilStaff), wrapped too when a wrap is worn over it.
local skinBodies = {}          -- [palette Id] = recoloured MeshPart | "building" | false (failed)
local function skinBody(template, pal)
	local got = skinBodies[pal.Id]
	if got ~= nil then return (got ~= "building" and got) or nil end
	skinBodies[pal.Id] = "building"
	task.spawn(function()
		local ok, mp = pcall(function()
			local AS = game:GetService("AssetService")
			local em = AS:CreateEditableMeshAsync(Content.fromUri(template.MeshId))
			local lo, hi = math.huge, -math.huge
			for _, v in ipairs(em:GetVertices()) do
				local y = em:GetPosition(v).Y
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
			for _, f in ipairs(em:GetFaces()) do
				local vs, cs = em:GetFaceVertices(f), em:GetFaceColors(f)
				for k = 1, #cs do
					local c = em:GetColor(cs[k])
					local shade = math.clamp((0.3 * c.R + 0.59 * c.G + 0.11 * c.B) / 0.30, 0.45, 1.25)
					local base = pal.At((em:GetPosition(vs[k]).Y - lo) / math.max(1e-3, hi - lo))
					em:SetColor(cs[k], Color3.new(math.min(1, base.R * shade), math.min(1, base.G * shade), math.min(1, base.B * shade)))
				end
			end
			return AS:CreateMeshPartAsync(Content.fromObject(em))
		end)
		skinBodies[pal.Id] = ok and mp or false
		if not ok then warnOnce("skinbody:" .. tostring(pal.Id), "skinned staff body: " .. tostring(mp)) end
	end)
	return nil
end

--- one trident part from RadiantDevilStaffData (`recol(colour, u)`: a wrap's colours by height), flat-shaded with the
--- head smooth above `smoothFrom` -- RadiantAnim's buildDevilPart
local function buildDevilPart(d, smoothFrom, recol)
	local AS = game:GetService("AssetService")
	local em = AS:CreateEditableMesh()
	local Pd, vids, pos = d.P, {}, {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 1, #Pd, 3 do
		local v = Vector3.new(Pd[i], Pd[i + 1], Pd[i + 2])
		vids[#vids + 1] = em:AddVertex(v)
		pos[#pos + 1] = v
		lo, hi = lo:Min(v), hi:Max(v)
	end
	local cols = nil
	if d.C then
		cols = {}
		for k, hx in ipairs(d.C) do
			cols[k] = em:AddColor(Color3.fromRGB(bit32.rshift(hx, 16), bit32.band(bit32.rshift(hx, 8), 255), bit32.band(hx, 255)), 1)
		end
	end
	local base, rcols = {}, {}
	if recol and d.C then
		for k, hx in ipairs(d.C) do
			base[k] = Color3.fromRGB(bit32.rshift(hx, 16), bit32.band(bit32.rshift(hx, 8), 255), bit32.band(hx, 255))
		end
	end
	local function colId(k, y)
		if not recol then return cols[k] end
		local b = math.floor(math.clamp((y - lo.Y) / math.max(1e-3, hi.Y - lo.Y), 0, 1) * 15 + 0.5)
		local key = k * 16 + b
		local id = rcols[key]
		if not id then
			id = em:AddColor(recol(base[k], b / 15), 1)
			rcols[key] = id
		end
		return id
	end
	local T, TC = d.T, d.TC
	local fn, fa, around = {}, {}, {}
	for t = 1, #T, 3 do
		local a, b, c = T[t], T[t + 1], T[t + 2]
		local n = (pos[b] - pos[a]):Cross(pos[c] - pos[a])
		local m = n.Magnitude
		fn[t], fa[t] = m > 1e-9 and n / m or nil, m
		if smoothFrom then
			for _, v in ipairs({ a, b, c }) do
				local l = around[v] or {}
				around[v] = l
				l[#l + 1] = t
			end
		end
	end
	local ncache = {}
	local function smoothId(n)
		local k = string.format("%.3f,%.3f,%.3f", n.X, n.Y, n.Z)
		local id = ncache[k]
		if not id then
			id = em:AddNormal(n)
			ncache[k] = id
		end
		return id
	end
	for t = 1, #T, 3 do
		local a, b, c = T[t], T[t + 1], T[t + 2]
		local f = em:AddTriangle(vids[a], vids[b], vids[c])
		local n = fn[t]
		if n and smoothFrom and pos[a].Y > smoothFrom and pos[b].Y > smoothFrom and pos[c].Y > smoothFrom then
			local ids = {}
			for i, v in ipairs({ a, b, c }) do
				local s = Vector3.zero
				for _, u in ipairs(around[v]) do
					local nu = fn[u]
					if nu and nu:Dot(n) >= SMOOTH_COS then s += nu * fa[u] end
				end
				ids[i] = smoothId(s.Magnitude > 1e-9 and s.Unit or n)
			end
			em:SetFaceNormals(f, ids)
		elseif n then
			local nid = em:AddNormal(n)
			em:SetFaceNormals(f, { nid, nid, nid })
		end
		if cols then em:SetFaceColors(f, { colId(TC[t], pos[a].Y), colId(TC[t + 1], pos[b].Y), colId(TC[t + 2], pos[c].Y) }) end
	end
	local fixed = AS:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	em:Destroy()
	return AS:CreateMeshPartAsync(Content.fromObject(fixed)), (lo + hi) / 2, hi - lo
end

local devilBodies = {}         -- [palette Key, or "Devil"] = { Body, BodyC, BodySize, Lines, LinesC, LinesSize, Tip } | "building" | false
--- the trident for palette `pal` (a wrap worn over the skin: its own build in the wrap's colours), nil while it builds.
--- Never waits: RadiantDevilStaffData is required on the loop thread first (staffUp)
local function devilStaff(pal)
	local wrapped = pal.Wrap ~= nil and pal.At ~= nil
	local key = wrapped and (pal.Key or pal.Wrap) or "Devil"
	local got = devilBodies[key]
	if got ~= nil then return (got ~= "building" and got) or nil end
	local D = need("RadiantDevilStaffData", true)
	if not (type(D) == "table" and D.Body and D.Lines) then return nil end
	devilBodies[key] = "building"
	task.spawn(function()
		local ok, res = pcall(function()
			local recol = wrapped and function(_c, u) return pal.At(u) end or nil
			local b, bc, bs = buildDevilPart(D.Body, SMOOTH_HEAD_FROM, recol)
			local l, lc, ls = buildDevilPart(D.Lines)
			return { Body = b, BodyC = bc, BodySize = bs, Lines = l, LinesC = lc, LinesSize = ls, Tip = D.Tip }
		end)
		devilBodies[key] = ok and res or false
		if not ok then warnOnce("devil:" .. key, "devil staff: " .. tostring(res)) end
	end)
	return nil
end

-- THE PROP: RadiantAnim's Staff, for one body (scale 1: the world staff)
local Prop = {}
Prop.__index = Prop

--- StaffA's Body + Lines, from RadiantAnim's own asset paths
local function staffTemplate(A)
	local paths = (type(A.Config) == "table" and type(A.Config.AssetPaths) == "table") and A.Config.AssetPaths or STAFF_PATHS
	for _, path in ipairs(paths) do
		local node = ReplicatedStorage
		for _, n in ipairs(path) do node = node and node:FindFirstChild(n) end
		if node then
			local body, lines = node:FindFirstChild("Body"), node:FindFirstChild("Lines")
			if body and body:IsA("BasePart") and lines and lines:IsA("BasePart") then return body, lines end
		end
	end
	return nil, nil
end

--- RadiantAnim's newStaff: the two parts cloned clean (no joints), anchored and inert, sized and offset by StaffGeometry
local function newStaff(A, G, parent)
	local bodyT, linesT = staffTemplate(A)
	if not bodyT then
		warnOnce("staffasset", "no staff asset at ReplicatedStorage.RadiantAssets.StaffA (Body + Lines): no staff in hand")
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "RadiantStaff_AltarCaster"
	local function prep(tpl, geo)
		local p = tpl:Clone()
		for _, d in ipairs(p:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Attachment") then d:Destroy() end
		end
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
		local ts = tpl:GetAttribute("TemplateSize")
		if typeof(ts) ~= "Vector3" then ts = (type(geo) == "table" and geo.TemplateSize) or tpl.Size end
		p.Size = ts
		local ofp = tpl:GetAttribute("OriginFromPivot")
		if typeof(ofp) ~= "Vector3" then ofp = (type(geo) == "table" and geo.OriginFromPivot) or Vector3.zero end
		p.Parent = model
		return p, CFrame.new(-ofp)
	end
	local body, bodyOfs = prep(bodyT, G.Body)
	local lines, linesOfs = prep(linesT, G.Lines)
	model.Parent = parent
	return setmetatable({ Model = model, Body = body, BodyT = bodyT, Lines = lines, LinesT = linesT, BodyOfs = bodyOfs,
		LinesOfs = linesOfs, Shown = true, Q = -1, QPal = nil, Frame = nil, BodySkin = "Default" }, Prop)
end

function Prop:Place(F)
	self.Frame = F
	self.Body.CFrame = F * self.BodyOfs
	self.Lines.CFrame = F * self.LinesOfs
end

function Prop:Show(on)
	if on == self.Shown then return end
	self.Shown = on
	local tr = on and 0 or 1
	self.Body.Transparency = tr
	self.Lines.Transparency = tr
end

--- the trident on (dv) or StaffA back (nil): meshes, sizes, offsets from the staff frame (RadiantAnim's UseDevil)
function Prop:UseDevil(dv)
	if dv and not self.Orig then
		self.Orig = { BodySize = self.Body.Size, BodyOfs = self.BodyOfs, LinesSize = self.Lines.Size, LinesOfs = self.LinesOfs }
	end
	if dv then
		pcall(function() self.Body:ApplyMesh(dv.Body) end)
		pcall(function() self.Lines:ApplyMesh(dv.Lines) end)
		local sl = Vector3.new(0, DEVIL_TP_SLIDE, 0)
		self.Body.Size, self.BodyOfs = dv.BodySize, CFrame.new(dv.BodyC - sl)
		self.Lines.Size, self.LinesOfs = dv.LinesSize, CFrame.new(dv.LinesC - sl)
	elseif self.Devil and self.Orig then
		pcall(function() self.Body:ApplyMesh(self.BodyT) end)
		pcall(function() self.Lines:ApplyMesh(self.LinesT) end)
		self.Body.Size, self.BodyOfs = self.Orig.BodySize, self.Orig.BodyOfs
		self.Lines.Size, self.LinesOfs = self.Orig.LinesSize, self.Orig.LinesOfs
	end
	self.Devil = dv
	if self.Frame then self:Place(self.Frame) end
end

--- the engraving at `level` in palette `pal` (the caster's Light Lance look, the staff being the M1's), and the body
--- the look gives it -- RadiantAnim's Staff:Glow
function Prop:Glow(level, pal)
	local q = math.floor(clamp01(level) * 128 + 0.5)
	local want = pal and (pal.Key or pal.Id) or "Default"
	if self.BodySkin ~= want and pal and pal.Staff == "Devil" then
		local dv = devilStaff(pal)
		if dv then
			self.BodySkin = want
			self:UseDevil(dv)
		end
	elseif self.BodySkin ~= want then
		local src = pal and skinBody(self.BodyT, pal) or (not pal and self.BodyT) or nil
		if src then
			if self.Devil then self:UseDevil(nil) end
			self.BodySkin = want
			local size = self.Body.Size
			pcall(function() self.Body:ApplyMesh(src) end)
			self.Body.Size = size
		end
	end
	local key = pal and (q + 1000) or q
	if key == self.Q and pal == self.QPal then return end
	self.Q, self.QPal = key, pal
	local RD = need("RadiantDraw", true)
	if RD and type(RD.StaffGlow) == "function" and pcall(RD.StaffGlow, { self.Lines }, q / 128, pal) then return end
	local l = q / 128
	self.Lines.Material = l >= 0.25 and Enum.Material.Neon or Enum.Material.SmoothPlastic
	self.Lines.Color = l <= 0.5 and LINE_IDLE:Lerp(GOLD, l / 0.5) or GOLD:Lerp(INLAY_HOT, (l - 0.5) / 0.5)
end

--- a named point of the staff in the world ("tip" / "butt" / "grip_front" / the grip) -- RadiantAnim's Staff:Point
function Prop:Point(name)
	local P = need("RadiantPoseTable", true)
	if not (self.Frame and P and type(P.StaffGeometry) == "table") then return nil end
	local G = P.StaffGeometry
	local v = (name == "tip" and ((self.Devil and self.Devil.Tip) or G.Tip)) or (name == "butt" and G.Butt)
		or (name == "grip_front" and G.GripFront) or Vector3.zero
	if self.Devil and v ~= Vector3.zero then
		return self.Frame:PointToWorldSpace(v - Vector3.new(0, DEVIL_TP_SLIDE, 0))
	end
	return self.Frame:PointToWorldSpace(v)
end

-- THE HOLD: a staff frame is the main grip, UpVector the long axis, LookVector the front face (RadiantAnim's frames)
local function frameAxisFront(grip, axis, front)
	local y = axis.Unit
	local f = front - y * front:Dot(y)
	if f.Magnitude < 1e-4 then
		f = (math.abs(y.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis):Cross(y)
	end
	local z = -f.Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(grip, x, y, z)
end

local function frameAxisUp(grip, axis)
	local y = axis.Unit
	local upP = Vector3.yAxis - y * y.Y
	if upP.Magnitude < 1e-4 then return frameAxisFront(grip, y, -Vector3.zAxis) end
	local x = -upP.Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(grip, x, y, z)
end

--- the body's parts the hold reads (RadiantAnim's refreshParts)
local function heldParts(H)
	local c = H.Character
	H.Root = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
	H.UpperTorso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
	H.RightHand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	H.LeftHand = c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm")
end

--- the torso's heading, yaw only (it carries Halo's spin and the waist's Turn)
local function bodyBasis(H)
	local ut = H.UpperTorso
	local look = ut and ut.Parent and ut.CFrame.LookVector or H.Root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then flatLook = H.Root.CFrame.LookVector * Vector3.new(1, 0, 1) end
	if flatLook.Magnitude < 1e-3 then flatLook = -Vector3.zAxis end
	local p = H.Root.Position
	return CFrame.lookAt(p, p + flatLook.Unit)
end

local function handGrip(H, side, G)
	local hand = side == "L" and H.LeftHand or H.RightHand
	if not (hand and hand.Parent) then return nil end
	return hand.CFrame:PointToWorldSpace(G.GripOnHand)
end

local function plantFrame(H, mode, basis, G)
	local pl = H.Plant
	if not pl then return nil end
	local at = pl.Point or (H.Root.Position + basis:VectorToWorldSpace(G.PlantOffset))
	local lift = (mode == "raise" and G.RaiseLift) or (mode == "pulled" and G.PullLift) or 0
	local buttY = pl.FloorY - G.Sink + lift
	return frameAxisFront(Vector3.new(at.X, buttY - G.Butt.Y, at.Z), Vector3.yAxis, pl.Look or basis.LookVector)
end

local function bodyFrame(H, mode, basis, G)
	if WORLD[mode] then return plantFrame(H, mode, basis, G) end
	local gr = handGrip(H, "R", G)
	if not gr then return nil end
	if mode == "two_hand" or mode == "two_hand_f" then
		local gl = handGrip(H, "L", G)
		local ax = gl and (gl - gr) or basis.LookVector
		if ax.Magnitude < 0.05 then ax = basis.LookVector end
		if mode == "two_hand" then return frameAxisUp(gr, ax) end
		return frameAxisFront(gr, ax, basis.LookVector)
	end
	local ax = basis:VectorToWorldSpace(mode == "press" and G.PressAxis or G.CarryAxis)
	return frameAxisFront(gr, ax, basis.LookVector)
end

--- the hold now: modeA, and (modeB, u) while a segment blends A -> B (RadiantAnim's holdNow)
local function holdNow(H)
	local tr = H.Track
	if not tr then return "carry" end
	local t = tr.Clock()
	local segs = tr.Segs
	for _, sg in ipairs(segs) do
		if t < sg.T1 then
			if t < sg.T0 then return sg.From or sg.Mode end
			if sg.From then
				return sg.From, sg.Mode, easeOut(sg.Ease, (t - sg.T0) / math.max(1e-4, sg.T1 - sg.T0))
			end
			return sg.Mode
		end
	end
	local last = segs[#segs]
	if last.Mode == "carry" and not tr.Hold then H.Track = nil end
	return last.Mode
end

local function setTrack(H, name, clock, hold)
	local P = need("RadiantPoseTable", true)
	local segs = P and type(P.Staff) == "table" and P.Staff[name]
	if not segs then return end
	H.Track = { Name = name, Segs = segs, Clock = clock, Hold = hold }
end

--- a held track let go: blended from its hold back to the carry
local function releaseTrack(H, name)
	local P = need("RadiantPoseTable", true)
	local r = P and type(P.StaffRelease) == "table" and P.StaffRelease[name]
	if not (H.Track and H.Track.Name == name) then return end
	if not r then
		H.Track = nil
		return
	end
	H.Track = { Name = name .. "_Release", Segs = { { T0 = 0, T1 = r.Dur, Mode = "carry", From = r.From, Ease = r.Ease } },
		Clock = clockFrom(os.clock()) }
end

-- THE GLOW: sources fn(now) -> level | nil (done); the staff shows the brightest (RadiantAnim's glowOn / glowLevel)
local function glowLevel(H, now)
	local best = 0
	for key, fn in pairs(H.Glows) do
		local ok, l = pcall(fn, now)
		if not ok or l == nil then
			H.Glows[key] = nil
		elseif l > best then
			best = l
		end
	end
	return best
end

local function envGlow(start, spec)
	return function(now)
		local e = (now - start) * timeScale()
		if e >= spec[2] then return nil end
		return env(e, spec[1], spec[2], spec[3], spec[4])
	end
end

local function lerpFrame(a, b, u)
	if not a then return b end
	if not b then return a end
	return a:Lerp(b, u)
end

local function handVisible(H)
	local h = H.RightHand
	if not (h and h.Parent) then return false end
	return h.Transparency < 0.99 and h.LocalTransparencyModifier < 0.99
end

--- one frame of the staff (RadiantAnim's step, for one non-player body: the world staff only)
local function heldStep(H)
	local st = H.Staff
	if not (H.Character.Parent and H.Root and H.Root.Parent) then
		st:Show(false)
		return
	end
	if not (H.RightHand and H.RightHand.Parent and H.UpperTorso and H.UpperTorso.Parent) then heldParts(H) end
	local P = need("RadiantPoseTable", true)
	local G = P and P.StaffGeometry
	if type(G) ~= "table" then return end
	local level = glowLevel(H, os.clock())
	H.Level = level
	local a, b, u = holdNow(H)
	local basis = bodyBasis(H)
	local fa = bodyFrame(H, a, basis, G)
	local f = b and lerpFrame(fa, bodyFrame(H, b, basis, G), u) or fa
	if f then
		st:Place(f)
		st:Glow(level, H.Pal)
		st:Show(handVisible(H) and next(H.HiddenBy) == nil)
	else
		st:Show(false)
	end
end

-- RADIANTANIM'S STAFF READS, taught the preview's dummies: each read on the module table answers for a body this module
-- holds a staff for, and goes to RadiantAnim for every other body. Registered on the table itself (_AltarStaffs), so a
-- second copy of this module shares it; put back as RadiantAnim had them once no preview holds a staff.
local ANSWER = {
	StaffPoint = function(H, name) return H.Staff:Point(name) end,
	StaffCFrame = function(H) return H.Staff.Frame end,
	StaffLevel = function(H) return H.Level end,
	PlantPoint = function(H)
		if not (H.Plant and H.Track and H.Track.Name == "RadiantBenediction") then return nil end
		return H.Staff:Point("butt")
	end,
	SetStaffHidden = function(H, hidden, who) H.HiddenBy[who or "default"] = hidden and true or nil end,
}

local function staffReads(A)
	local reg = rawget(A, "_AltarStaffs")
	if type(reg) ~= "table" then
		reg = { Held = setmetatable({}, { __mode = "k" }), Base = {}, Fn = {} }
		A._AltarStaffs = reg
	end
	for name, answer in pairs(ANSWER) do
		local cur = A[name]
		if type(cur) == "function" and cur ~= reg.Fn[name] then
			local base = cur
			local fn = function(character, ...)
				local H = typeof(character) == "Instance" and reg.Held[character] or nil
				if H then return answer(H, ...) end
				return base(character, ...)
			end
			reg.Base[name], reg.Fn[name] = base, fn
			A[name] = fn
		end
	end
	return reg
end

local function staffReadsRelease(A)
	local reg = A and rawget(A, "_AltarStaffs")
	if type(reg) ~= "table" or next(reg.Held) ~= nil then return end
	for name, fn in pairs(reg.Fn) do
		if A[name] == fn then A[name] = reg.Base[name] end              -- (never undo somebody else's wrapper)
	end
	table.clear(reg.Fn)
	table.clear(reg.Base)
end

--- the floor under `at`, the bodies and the FX looked through (RadiantAnim's floorUnder)
local function floorUnder(run, at)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { run.Caster }
	if run.Target then list[#list + 1] = run.Target end
	if workspace.CurrentCamera then list[#list + 1] = workspace.CurrentCamera end
	local fx = workspace:FindFirstChild("IceMagicFX")
	if fx then list[#list + 1] = fx end
	params.FilterDescendantsInstances = list
	local hit = workspace:Raycast(at, Vector3.new(0, -12, 0), params)
	if hit then return hit.Position.Y end
	local fl = run.Stage.Floor
	return typeof(fl) == "Vector3" and fl.Y or (at.Y - 3.192)
end

local staffSeq = 0
--- the caster's staff, up for this preview (on its loop thread: it may wait for the modules), stepped every frame, and
--- RadiantAnim's reads taught it; all of it taken down on stop (run.Keep)
--- (2026-10-26) the caches below are EditableMesh copies: MeshBudget may take them back while no altar staff is up
local liveStaffs, budgetIn = 0, false
local function releaseBodies()
	if liveStaffs > 0 then return end
	for k, v in pairs(skinBodies) do
		if typeof(v) == "Instance" then pcall(v.Destroy, v) skinBodies[k] = nil end
	end
	for k, v in pairs(devilBodies) do
		if type(v) == "table" then
			pcall(function() v.Body:Destroy() end)
			pcall(function() v.Lines:Destroy() end)
			devilBodies[k] = nil
		end
	end
end
local function staffUp(run)
	local A, P = need("RadiantAnim"), need("RadiantPoseTable")
	if not (A and P and type(P.StaffGeometry) == "table" and run.Alive) then
		if run.Alive then warnOnce("staffmods", "RadiantAnim / RadiantPoseTable unavailable: the caster holds no staff") end
		return
	end
	if run.Pal and run.Pal.Staff == "Devil" then need("RadiantDevilStaffData") end
	local parent = typeof(run.Stage.Parent) == "Instance" and run.Stage.Parent or workspace
	if not budgetIn then
		budgetIn = true
		local MB = need("MeshBudget")
		if MB then MB.Optional(releaseBodies) end
	end
	local st = newStaff(A, P.StaffGeometry, parent)
	if not st then return end
	liveStaffs += 1
	local H = { Character = run.Caster, Staff = st, Pal = run.Pal, Glows = {}, HiddenBy = {}, Level = 0 }
	heldParts(H)
	st:Glow(0, H.Pal)
	local reg = staffReads(A)
	reg.Held[run.Caster] = H
	run.Held = H
	staffSeq += 1
	local name = "AltarRadiantStaff" .. staffSeq
	RunService:BindToRenderStep(name, STAFF_PRIORITY, function()
		if run.SpinTick then pcall(run.SpinTick) end
		local ok, err = pcall(heldStep, H)
		if not ok then warnOnce("staffstep", "staff: " .. tostring(err)) end
	end)
	run.Keep(function()
		pcall(RunService.UnbindFromRenderStep, RunService, name)
		if reg.Held[run.Caster] == H then reg.Held[run.Caster] = nil end
		pcall(staffReadsRelease, A)
		pcall(function() st.Model:Destroy() end)
		liveStaffs -= 1
		if run.Held == H then run.Held = nil end
	end)
end

-- THE STAFF'S PART IN EACH BEAT: what RadiantAnim's handlers do to a Radiant body's staff for the broadcast this module
-- sends (its hold track, its glow source); nothing without a staff
--- Light Lance on: the two-hand hold (held) and the gather-then-ramp glow; returns the beam's record (its Ramp is the
--- server's, set by the caller; ReleasedAt on the let-go)
local function heldLance(run)
	local H, P = run.Held, need("RadiantPoseTable", true)
	if not (H and P and type(P.Timing) == "table") then return nil end
	local TL = P.Timing.Lance
	local L = { Start = os.clock(), Ramp = 0, Level = 0 }
	H.Lance = L
	setTrack(H, "RadiantLance", clockFrom(L.Start), true)
	H.Glows.lance = function(now)
		if H.Lance ~= L then return nil end
		if L.ReleasedAt then
			local e = (now - L.ReleasedAt) * timeScale()
			if e >= TL.ReleaseFade then
				H.Lance = nil
				return nil
			end
			return L.Level * (1 - ramp(e, 0, TL.ReleaseFade))
		end
		local e = (now - L.Start) * timeScale()
		local g = 0.5 * ramp(e, TL.GlowFrom, TL.GlowRamp)
		if e >= TL.Fire then g = math.max(g, 0.5 + 0.5 * clamp01(L.Ramp) ^ 1.2) end
		L.Level = g
		return g
	end
	return L
end

local function heldLanceOff(run, L)
	if L and not L.ReleasedAt then L.ReleasedAt = os.clock() end
	if run.Held then releaseTrack(run.Held, "RadiantLance") end
end

--- a one-shot flash of RadiantPoseTable.Timing[timing].Glow (Blessing; Overflow's payoff)
local function heldFlash(run, key, timing)
	local H, P = run.Held, need("RadiantPoseTable", true)
	local spec = P and type(P.Timing) == "table" and type(P.Timing[timing]) == "table" and P.Timing[timing].Glow or nil
	if H and type(spec) == "table" then H.Glows[key] = envGlow(os.clock(), spec) end
end

--- Position Trade's tap (the press hold) and its flash, dark while the body is gone, on `clock` (the press's)
local function heldTrade(run, clock)
	local H, P = run.Held, need("RadiantPoseTable", true)
	if not (H and P and type(P.Timing) == "table") then return end
	local TT = P.Timing.Trade
	setTrack(H, "RadiantTrade", clock, false)
	H.Glows.trade = function()
		local e = clock()
		if e >= TT.Hidden[2] + TT.BackFade then return nil end
		if e < TT.Hidden[1] then return ramp(e, TT.Rise[1], TT.Rise[2]) end
		if e < TT.Hidden[2] then return 0 end
		return TT.Back * (1 - ramp(e, TT.Hidden[2], TT.BackFade))
	end
end

--- Halo's windup hold (two_hand_f, back to the carry after the lock) and its glow: lit to the lock, dimmed to the window,
--- faded from the End (the record's EndedAt)
local function heldHalo(run, clock)
	local H, P = run.Held, need("RadiantPoseTable", true)
	if not (H and P and type(P.Timing) == "table") then return nil end
	local TH = P.Timing.Halo
	local R = { Clock = clock, Level = 0 }
	H.Halo = R
	setTrack(H, "RadiantHaloWindup", clock, false)
	H.Glows.halo = function(now)
		if H.Halo ~= R then return nil end
		if R.EndedAt then
			local e = (now - R.EndedAt) * timeScale()
			if e >= TH.EndFade then
				H.Halo = nil
				return nil
			end
			return R.EndLevel * (1 - ramp(e, 0, TH.EndFade))
		end
		local t = R.Clock()
		local g = ramp(t, 0, TH.Lock) - (1 - TH.Window) * ramp(t, TH.DimFrom, TH.DimFor)
		R.Level = g
		return g
	end
	return R
end

local function heldHaloEnd(R)
	if R and not R.EndedAt then R.EndedAt, R.EndLevel = os.clock(), R.Level end
end

--- Benediction: the plant fixed in the world where the channel starts (`at`, the server's At), the lift-drive-kneel-
--- pull hold on the kneel's `clock`, and the glow -- pre-glow to the plant, lit while planted with a flash on every
--- server pulse (B.T0 + k x `every`), faded from B.EndAt
local function heldBenediction(run, clock, B, every, at)
	local H, P = run.Held, need("RadiantPoseTable", true)
	if not (H and P and type(P.Timing) == "table" and H.Root) then return end
	local G, TB = P.StaffGeometry, P.Timing.Benediction
	local basis = bodyBasis(H)
	H.Plant = { FloorY = floorUnder(run, at), At = at, Look = basis.LookVector,
		Point = at + basis:VectorToWorldSpace(G.PlantOffset) }
	setTrack(H, "RadiantBenediction", clock, false)
	H.Glows.benediction = function(now)
		if B.EndAt and B.EndLevel then
			local e = (now - B.EndAt) * timeScale()
			if e >= TB.EndFade then return nil end
			return B.EndLevel * (1 - ramp(e, 0, TB.EndFade))
		end
		local t = clock()
		local g
		if t < TB.Plant then
			g = TB.PreGlow * ramp(t, 0, TB.Plant)
		else
			g = 1 - (1 - TB.Floor) * ramp(t, TB.Settle[1], TB.Settle[2])
			local sn, pe, pl = serverNow(), 0, TB.Pulse
			local k0 = math.floor((sn - B.T0) / every)
			for k = math.max(1, k0), k0 + 1 do
				local ta = B.T0 + k * every
				pe = math.max(pe, env(sn, ta + pl[1], ta + pl[2], pl[3], pl[4]))
			end
			g = math.max(g, TB.Floor + (1 - TB.Floor) * pe)
		end
		B.Level = g
		if B.EndAt then B.EndLevel = g end
		return g
	end
end

----------------------------------------------------------------------------------------------------
-- the looks: RadiantClient.Handlers, every RadiantDraw effect they start caught for stop()
----------------------------------------------------------------------------------------------------
local STAFF_KINDS = { RadiantHaloCharge = true, RadiantHaloCancel = true, RadiantHaloStart = true, RadiantHaloEnd = true,
	RadiantBenedictionStart = true, RadiantBenedictionPulse = true, RadiantBenedictionEnd = true }
local HAND_KINDS = { RadiantBlessing = true, RadiantOverflow = true, RadiantTradeOut = true, RadiantTradeIn = true }

--- fn(d), with every RadiantDraw.Play it makes caught into the run (RadiantFX_Staff / _Hand keep their handles to
--- themselves). Both call RadiantDraw.Play through the module table, so it is wrapped for the length of this
--- synchronous call and put straight back; only effects of the stage's own bodies (or ownerless ones) are kept
local function caught(run, fn, d)
	local RD = need("RadiantDraw", true)
	local orig = RD and RD.Play
	if type(orig) ~= "function" then return pcall(fn, d) end
	local got = {}
	local function spy(...)
		local e = orig(...)
		got[#got + 1] = e
		return e
	end
	local swapped = pcall(function() RD.Play = spy end)
	local ok, err = pcall(fn, d)
	if swapped and RD.Play == spy then RD.Play = orig end
	for _, e in ipairs(got) do
		local cv = type(e) == "table" and e.Canvas or nil
		local owner = type(cv) == "table" and cv.Owner or nil
		if owner == nil or owner == run.Caster or owner == run.Target then run.Fx(e) end
	end
	return ok, err
end

--- one broadcast, drawn the way every other client draws it: RadiantClient.Handlers[kind](d), the payload stamped with
--- the wrap (RadiantHandler stamps the caster's Skin on every Radiant broadcast). No RadiantClient: the piece's own
--- handler in the wrap's palette (RadiantClient's handle()), the lance kinds excepted (warned)
local function deliver(run, kind, d)
	d.Skin = run.Id                                               -- (2026-10-26: the look's stamp, skin and wrap -- lookOf)
	local nowait = not run.Alive                                  -- stop()'s path never waits for a module
	local RC = need("RadiantClient", nowait)
	local f = RC and type(RC.Handlers) == "table" and RC.Handlers[kind] or nil
	if type(f) ~= "function" then
		local mod = (STAFF_KINDS[kind] and need("RadiantFX_Staff", nowait))
			or (HAND_KINDS[kind] and need("RadiantFX_Hand", nowait)) or nil
		local h = mod and type(mod.Handlers) == "table" and mod.Handlers[kind] or nil
		if type(h) ~= "function" then
			warnOnce("kind:" .. kind, kind .. ": no RadiantClient handler, nothing drawn")
			return
		end
		local SC = need("SkinCatalog", nowait)
		local pal = SC and palette(SC.AbilityOfKind(kind), run.Id) or nil
		f = function(dd) return skinned(pal, h, dd) end
	end
	local ok, err = caught(run, f, d)
	if not ok then warnOnce("send:" .. kind, kind .. ": " .. tostring(err)) end
end

local function send(run, kind, d)
	if run.Alive then deliver(run, kind, d) end
end

----------------------------------------------------------------------------------------------------
-- the target's side: AltarStage's React, and the heal readout
----------------------------------------------------------------------------------------------------
local function hit(run, opts)
	local R = run.React
	if not (run.Alive and type(R) == "table" and type(R.Hit) == "function") then return end
	local ok, err = pcall(R.Hit, run.Stage, opts)
	if not ok then warnOnce("hit", "React.Hit: " .. tostring(err)) end
end

local healReady = false
--- RadiantHandler's heal readout style, on the client's Callouts (the server registers it on its own copy only)
local function healStyle()
	if healReady then return end
	local C, T = need("Callouts"), need("RadiantTuning")
	if not (C and type(C.Styles) == "table") then return end
	healReady = true
	local H = T and T.HealPop
	if C.Styles.heal or type(H) ~= "table" then return end
	C.Styles.heal = { TextSize = H.TextSize, Stroke = H.Stroke, Color = H.Colour, Tilt = 4, Life = H.Life,
		Shift = Vector2.new(-0.6, -0.4), Slot = "heal" }
end

local function popOn(m, offset, text, style)
	local C = need("Callouts", true)
	local head = partOf(m, "Head")
	if C and head then pcall(C.Pop, head, offset, text, style) end
end

--- "+N" over a healed body, where RadiantHandler pops it (Head + 1.6), and the health it restores
local function healPop(run, m, amount)
	if not (run.Alive and typeof(m) == "Instance" and m.Parent) then return end
	local n = math.floor(amount + 0.5)
	if n < 1 then return end
	popOn(m, Vector3.new(0, 1.6, 0), "+" .. n, "heal")
	local h = m:FindFirstChildOfClass("Humanoid")
	if h then h.Health = math.min(h.MaxHealth, h.Health + amount) end
end

----------------------------------------------------------------------------------------------------
-- THE LOOP: cast(run) once every `every` seconds in a thread of its own (it waits inside with run.Sleep) until stop()
----------------------------------------------------------------------------------------------------
local function home(run)
	if run.Caster.Parent then run.Caster:PivotTo(run.CasterHome) end
	if run.Target and run.Target.Parent and run.TargetHome then run.Target:PivotTo(run.TargetHome) end
end

--- between beats: the caster back on its rest (the carry, no aim, no held clip), both dummies home, React.Reset
local function rest(run)
	local CP = need("CastPose")
	local c = run.Caster
	if CP and c.Parent then
		pcall(CP.SetAim, c, nil)
		local cur = CP.CurrentClip(c)
		if type(cur) == "string" and string.sub(cur, 1, 7) == "Radiant" then pcall(CP.Stop, c) end
		if clips(CP) then pcall(CP.SetBase, c, "RadiantCarry") end
	end
	local H = run.Held                                           -- (2026-10-26) the staff back in the carry, unlit
	if H then
		H.Track, H.Plant, H.Lance, H.Halo = nil, nil, nil, nil
		table.clear(H.Glows)
		table.clear(H.HiddenBy)
	end
	home(run)
	if run.React and type(run.React.Reset) == "function" then pcall(run.React.Reset, run.Stage) end
end

local function looped(stage, every, cast, key)
	assert(type(stage) == "table" and typeof(stage.CF) == "CFrame", "stage has no CF")
	local caster = stage.Caster or stage.Key
	assert(typeof(caster) == "Instance" and caster:IsA("Model"), "stage has no Caster")
	local target = (typeof(stage.Target) == "Instance" and stage.Target:IsA("Model")) and stage.Target or nil
	local R = flat(stage.CF.RightVector, Vector3.xAxis)
	local skin, id = lookOf(stage)                                 -- (2026-10-26) the skin worn, and the stamp it draws by
	local run = {
		Alive = true, Stage = stage, Caster = caster, Target = target, R = R,
		L = flat(stage.CF.LookVector, Vector3.zAxis),               -- toward the camera's home side
		Skin = skin, Id = id, Pal = nil, Held = nil,                -- (Pal: the staff's palette; Held: the staff, staffUp)
		React = type(stage.React) == "table" and stage.React or nil,
		CasterHome = restCF(caster, R), TargetHome = target and restCF(target, -R) or nil,
		FX = {}, Live = {}, Kept = {}, Flags = {}, Seq = 0, EndSpin = nil,
	}

	--- waits s seconds (0: a frame); false once stopped -- every cast returns on false
	function run.Sleep(s)
		task.wait(math.max(s or 0, 0))
		return run.Alive
	end
	--- a caught RadiantDraw effect (stopped at once if the run is over)
	function run.Fx(e)
		if type(e) ~= "table" or type(e.Stop) ~= "function" then return end
		if not run.Alive then pcall(e.Stop, e) return end
		local L = run.FX
		for i = #L, 1, -1 do
			if L[i].Dead then table.remove(L, i) end                -- over by itself: dropped, so the list stays short
		end
		L[#L + 1] = e
	end
	--- a standing put-back (a flag, the HipHeight), run once on stop
	function run.Keep(fn)
		if not run.Alive then pcall(fn) return end
		run.Kept[#run.Kept + 1] = fn
	end
	--- the Blessed flag on `m` (its first value put back on stop)
	function run.Flag(m, on)
		if typeof(m) ~= "Instance" or not run.Alive then return end
		if not run.Flags[m] then
			run.Flags[m] = true
			local was = m:GetAttribute(BLESSED)
			run.Keep(function() if m.Parent then m:SetAttribute(BLESSED, was) end end)
		end
		m:SetAttribute(BLESSED, on)
	end
	--- the caster standing at its real HipHeight while a look reads it (Halo's airborne test), put back on stop
	function run.Stand()
		local h = caster:FindFirstChildOfClass("Humanoid")
		if run.Stood or not h or h.HipHeight >= HIP - 0.05 then return end
		run.Stood = true
		local was = h.HipHeight
		h.HipHeight = HIP
		run.Keep(function() if h.Parent then h.HipHeight = was end end)
	end

	local function stop()
		if not run.Alive then return end
		run.Alive = false
		for _, e in ipairs(run.FX) do pcall(e.Stop, e) end         -- every look this preview started: gone next frame
		table.clear(run.FX)
		for fn in pairs(run.Live) do pcall(fn) end                  -- the trackers told (the lance's Off, an End)
		table.clear(run.Live)
		if run.EndSpin then pcall(run.EndSpin) end
		for i = #run.Kept, 1, -1 do pcall(run.Kept[i]) end
		table.clear(run.Kept)
		local CP = need("CastPose", true)
		if CP and caster.Parent then
			pcall(CP.Stop, caster)
			pcall(CP.SetAim, caster, nil)
			pcall(CP.SetBase, caster, nil)
		end
		pcall(home, run)
		local React = run.React
		if type(React) == "table" and type(React.Reset) == "function" then pcall(React.Reset, stage) end
	end

	task.spawn(function()
		-- the modules first (this thread may wait for them; Play never does)
		run.React = run.React or need("AltarStage")
		for _, n in ipairs({ "CastPose", "RadiantPoseTable", "RadiantDraw", "RadiantClient", "RadiantTuning", "Callouts" }) do
			need(n)
		end
		local Staff = need("RadiantFX_Staff")
		if Staff and Staff.Prewarm then pcall(Staff.Prewarm) end   -- RadiantDraw's shared pool (idempotent; RadiantClient
		                                                            -- fills it only once somebody's Element is Radiant)
		healStyle()
		if run.Id and not palette(ABILITY[key] or "LightLance", run.Id) then
			warnOnce("wrap:" .. run.Id, "look " .. run.Id .. " does not resolve for Radiant " .. key .. ": it draws Default")
		end
		-- (2026-10-26) the skin's forms built ahead (RadiantClient's warmDevil, which only sees PLAYERS put it on), the
		-- staff's palette (its Light Lance look, as RadiantAnim's Staff:Glow takes it), and the staff in the caster's hand
		run.Pal = run.Id and palette("LightLance", run.Id) or nil
		if run.Pal and run.Pal.Id == "Devil" then
			if Staff and type(Staff.PrewarmDevil) == "function" then pcall(Staff.PrewarmDevil) end
			local Hd = need("RadiantFX_Hand")
			if Hd and type(Hd.PrewarmDevil) == "function" then pcall(Hd.PrewarmDevil) end
		end
		local okS, errS = pcall(staffUp, run)
		if not okS then warnOnce("staffup", "the staff could not be put in the caster's hand: " .. tostring(errS)) end
		while run.Alive do
			local t0 = os.clock()
			pcall(rest, run)
			if not run.Alive then break end
			local ok, err = pcall(cast, run)
			if not ok then warnOnce("cast:" .. key, key .. ": " .. tostring(err)) end
			if not run.Alive then break end
			task.wait(math.max(every - (os.clock() - t0), 0.05))
		end
	end)
	if typeof(stage.Parent) == "Instance" then
		pcall(function() stage.Parent.Destroying:Once(stop) end)  -- the stage cleared: nothing left running
	end
	return stop
end

----------------------------------------------------------------------------------------------------
-- shared beats
----------------------------------------------------------------------------------------------------
--- the beam's line, as another client draws it (RadiantClient: from the caster's head, to the server's claimed Point on
--- the body -- here the front of the target's chest)
local function aimLine(run)
	local head = partOf(run.Caster, "Head") or partOf(run.Caster, "HumanoidRootPart")
	local from = head and head.Position or (run.Stage.CF.Position - run.R * 7)
	local chest = chestOf(run.Target, run.Stage.CF.Position + run.R * 7)
	return from, chest + flat(from - chest, -run.R) * 0.5
end

--- THE LIGHT LANCE CHANNEL, RadiantHandler's way: RadiantLanceOn at the click (the body's RadiantLance with it), a
--- RadiantLance every 1/BroadcastRate with the server's ramp (0 on contact, 1 after RampTime on the one target), damage
--- in ticks of Tick on the target, RadiantLanceOff at the let-go (the release tail; the body eases home). `onTick(dmg)`
--- hears each tick (Halo's heal). Returns once let go, or stopped.
local function lanceRun(run, holdFor, onTick)
	local c, tgt = run.Caster, run.Target
	if not (run.Alive and tgt) then return end
	local T = need("RadiantTuning")
	local L = (T and type(T.LightLance) == "table") and T.LightLance or {}
	local rampTime, tick = L.RampTime or 2.0, L.Tick or 0.25
	local dps0, dps1 = L.DpsStart or 16, L.DpsMax or 32
	local say = 1 / (L.BroadcastRate or 10)
	local sc = timeScale()
	local contact = LANCE_CONTACT / sc
	run.Seq += 1
	local id = run.Seq
	local on = true
	local held = nil                                              -- (2026-10-26) the staff's beam record (heldLance)
	local off
	off = function()                                              -- the let-go (or stop(): RadiantClient's tracker let go)
		if not on then return end
		on = false
		run.Live[off] = nil
		heldLanceOff(run, held)
		deliver(run, "RadiantLanceOff", { Character = c, Reason = "Released", Id = id })
	end
	run.Live[off] = true
	pose(run, "RadiantLance")
	held = heldLance(run)                                         -- the staff to the two-hand hold, its gather glow
	send(run, "RadiantLanceOn", { Character = c, T0 = serverNow(), Id = id })
	local t0 = os.clock()
	local nextSay, nextTick, k, full = 0, contact, 0, false
	while run.Alive do
		local e = os.clock() - t0
		if e >= holdFor then break end
		local from, to = aimLine(run)
		if e >= nextSay then
			nextSay = e + say
			local ramp = math.clamp((e - contact) * sc / rampTime, 0, 1)
			if held then held.Ramp = ramp end                         -- (the server's Ramp lights the engraving)
			send(run, "RadiantLance", { Character = c, Dir = (to - from).Unit, Victim = tgt, Point = to, Ramp = ramp, Id = id })
		end
		while run.Alive and e >= nextTick do
			-- a tick: dps x Tick at this tick's ramp; a recoil on first contact and at the full-ramp payoff, else held
			local ramp = math.clamp((nextTick - contact) * sc / rampTime, 0, 1)
			local dmg = (dps0 + (dps1 - dps0) * ramp) * tick
			local payoff = ramp >= 1 and not full
			full = full or payoff
			hit(run, { Damage = dmg, From = from, NoRecoil = not (k == 0 or payoff) })
			if onTick then onTick(dmg) end
			k += 1
			nextTick += tick / sc
		end
		if not run.Sleep(0) then return end
	end
	if not run.Alive then return end
	off()
	unpose(run, "RadiantLance")
end

--- ONE POSITION TRADE from where both stand now: the staff tap (RadiantTrade on the press clock), RadiantTradeOut on its
--- Trigger, the Dissolve, then the server's swap -- each body to where the other stood, keeping its own facing -- and
--- RadiantTradeIn with the new spots (A = the caster's, B = the other's). False: stopped, or a body is missing.
local function tradeOnce(run)
	local c, o = run.Caster, run.Target
	local cr, orr = partOf(c, "HumanoidRootPart"), partOf(o, "HumanoidRootPart")
	if not (cr and orr) then return false end
	local T = need("RadiantTuning")
	local sc = timeScale()
	local dis = ((T and T.PositionTrade and T.PositionTrade.DissolveTime) or 0.12) / sc
	local press = clockFrom(os.clock())
	pose(run, "RadiantTrade", press)
	heldTrade(run, press)                                         -- (2026-10-26) the staff's tap and flash, on the press
	if not run.Sleep(trigger("RadiantTrade", 0.1) / sc) then return false end
	send(run, "RadiantTradeOut", { Character = c, Other = o, From = cr.Position, To = orr.Position, T0 = serverNow(),
		Dissolve = dis })
	if not run.Sleep(dis) then return false end
	local a, b = cr.CFrame, orr.CFrame
	local aTo = CFrame.new(b.Position) * (a - a.Position)
	local bTo = CFrame.new(a.Position) * (b - b.Position)
	c:PivotTo(aTo * (a:Inverse() * c:GetPivot()))                 -- each pivot keeps its offset from its root
	o:PivotTo(bTo * (b:Inverse() * o:GetPivot()))
	send(run, "RadiantTradeIn", { Character = c, Other = o, A = aTo.Position, B = bTo.Position, T0 = serverNow() })
	return true
end

--- the caster turned on the spot to face `look` over `dur` (a half turn goes round through the camera's side, so the
--- face is seen on the way)
local function turn(run, look, dur)
	local c = run.Caster
	local from = c:GetPivot()
	local p = from.Position
	local a0 = yawOf(from.LookVector)
	local d = wrapPi(yawOf(look) - a0)
	if math.abs(math.abs(d) - math.pi) < 0.05 then
		d = (wrapPi(yawOf(run.L) - a0) >= 0) and math.pi or -math.pi
	end
	local t0 = os.clock()
	repeat
		local u = math.clamp((os.clock() - t0) / math.max(dur, 1e-3), 0, 1)
		u = u * u * (3 - 2 * u)
		c:PivotTo(CFrame.new(p) * CFrame.Angles(0, a0 + d * u, 0))
	until u >= 1 or not run.Sleep(0)
	return run.Alive
end

----------------------------------------------------------------------------------------------------
-- THE MOVES (one beat each)
----------------------------------------------------------------------------------------------------
--- M1 LIGHT LANCE: the click into the two-handed hold, the held channel beam onto the target's chest, its ramp climbing
--- on the body (thicker core, rails, faster glyphs, the full-ramp payoff) while every tick lands, then the let-go
local function lanceCast(run)
	lanceRun(run, LANCE.Hold, nil)
end

--- PRIMARY BLESSING: the left palm raised (RadiantBlessing), the Bond from it to the ally, the Seraph Seal assembling
--- round them as BLESSED pops; the seal held, then the shield spent (the EMPTIED look). The target stands in as the ally
--- the aim picked (RadiantHandler's castBlessing: the ally nearest the aim line)
local function blessingCast(run)
	local c, tgt = run.Caster, run.Target
	if not tgt then return end
	pose(run, "RadiantBlessing")
	heldFlash(run, "blessing", "Blessing")                        -- (2026-10-26) the staff's one pulse
	run.Flag(tgt, true)                                           -- StatusEffects' Blessed goes up on the ally (the server)
	send(run, "RadiantBlessing", { Character = c, Target = tgt, T0 = serverNow() })
	if not run.Sleep(BLESS.Land) then return end
	hit(run, { Word = "BLESSED", Style = "blessed", NoRecoil = true })
	if not run.Sleep(BLESS.Hold - BLESS.Land) then return end
	run.Flag(tgt, false)                                          -- spent: the EMPTIED look, then the effect ends
end

--- MOBILITY POSITION TRADE: both spots gather and flash into their lantern cages, the golden bridge, the swap; a beat;
--- the caster (now facing away, as a trade leaves it) turns, trades back, and turns home
local function tradeCast(run)
	if not tradeOnce(run) then return end
	if not run.Sleep(TRADE.Wait) then return end
	if not turn(run, -run.R, TRADE.Turn) then return end
	if not tradeOnce(run) then return end
	if not run.Sleep(TRADE.Wait) then return end
	turn(run, run.R, TRADE.Turn)
end

--- DEFENSE BENEDICTION: the staff lifted and driven into the floor into the kneel (RadiantBenediction on RadiantAnim's
--- benClock: the payload's WindUp mapped onto the authored lift-and-drive, the plant key on the server's T0, the kneel
--- held until the End), the cracks, the turning sigil, the range ring, the sky sigil and its column into the raised
--- palm; a heal pulse every PulseEvery threads to the ally in range (stage.Target: "+8"); then the let-go (the rise)
local function beneCast(run)
	local c, tgt = run.Caster, run.Target
	local root = partOf(c, "HumanoidRootPart")
	if not root then return end
	local T, P = need("RadiantTuning"), need("RadiantPoseTable")
	local Bt = (T and type(T.Benediction) == "table") and T.Benediction or {}
	local TB = (P and type(P.Timing) == "table" and type(P.Timing.Benediction) == "table") and P.Timing.Benediction or {}
	local plant, hold = TB.Plant or 0.5, TB.Hold or 2.52
	local sc = timeScale()
	local windup, step = (Bt.WindUp or 0.5) / sc, (Bt.PulseEvery or 0.5) / sc
	local press = serverNow()
	local B = { T0 = press + windup, WindUp = windup, EndAt = nil }
	-- RadiantAnim's benClock (its missed-End timeout aside: the End always comes here)
	local benClock = function()
		if B.EndAt then return hold + (os.clock() - B.EndAt) * timeScale() end
		local r = (serverNow() - B.T0) * timeScale()
		local w = (B.WindUp > 0) and B.WindUp * timeScale() or plant
		return math.clamp(r >= 0 and (plant + r) or (plant + r * plant / w), 0, hold)
	end
	pose(run, "RadiantBenediction", benClock)
	local at = root.Position
	heldBenediction(run, benClock, B, step, at)                   -- (2026-10-26) the staff lifted, driven in, planted
	local allies = tgt and { tgt } or {}
	local ending
	ending = function()                                          -- stop() mid-channel: the End told (a caught look is gone)
		run.Live[ending] = nil
		deliver(run, "RadiantBenedictionEnd", { Character = c, Reason = "Cancelled", N = 0 })
	end
	run.Live[ending] = true
	-- RadiantHandler's castBenediction: T0 = the plant (press + WindUp), a pulse every Every after it (N from 1)
	send(run, "RadiantBenedictionStart", { Character = c, At = at, T0 = B.T0, TPress = press, WindUp = windup, Every = step,
		Allies = allies })
	for n = 1, BENE.Pulses do
		if not run.Sleep(B.T0 + n * step - serverNow()) then return end
		send(run, "RadiantBenedictionPulse", { Character = c, At = at, Targets = allies, Self = #allies == 0, N = n })
		healPop(run, tgt or c, Bt.HealPerPulse or 7.5)               -- pulseBenediction: every ally in Radius, else the caster
	end
	if not run.Sleep(0.05) then return end
	run.Live[ending] = nil
	B.EndAt = os.clock()
	send(run, "RadiantBenedictionEnd", { Character = c, Reason = "Released", N = BENE.Pulses })
end

--- ULTIMATE HALO: the windup (RadiantHaloWindup on RadiantAnim's haloClock, the body's two turns on the Root joint, the
--- staff tip's spiral), the ring locking over the head, the wings opening; under it a short Light Lance into the target
--- -- its ticks land and heal the caster by what they remove (Core.OnHitLanded's Halo conversion, capped at HealCap) --
--- then the End (the wings fold, the halo drops and unwinds)
local function haloCast(run)
	local c = run.Caster
	local T, P = need("RadiantTuning"), need("RadiantPoseTable")
	local H = (T and type(T.Halo) == "table") and T.Halo or {}
	local TH = (P and type(P.Timing) == "table" and type(P.Timing.Halo) == "table") and P.Timing.Halo or {}
	local lock = TH.Lock or 0.9
	local sc = timeScale()
	local windup, dur = (H.Windup or 0.9) / sc, (H.Duration or 6.0) / sc
	run.Stand()
	-- RadiantAnim's haloClock: the real Windup mapped onto the authored 0..lock, the rest at the clip rate
	local start = os.clock()
	local clock = function()
		local e = os.clock() - start
		if e <= windup then return lock * e / math.max(windup, 0.05) end
		return lock + (e - windup) * timeScale()
	end
	pose(run, "RadiantHaloWindup", clock)
	spin(run, clock)
	local held = heldHalo(run, clock)                            -- (2026-10-26) the staff raised two-handed, lit to the lock
	local ending
	ending = function()                                          -- stop() mid-Halo: its End told (a caught look is gone)
		run.Live[ending] = nil
		deliver(run, "RadiantHaloEnd", { Character = c, Reason = "Cancelled" })
	end
	run.Live[ending] = true
	-- RadiantHandler's castHalo: the charge, then openHalo a Windup later (T0 = its lock), then endHalo
	local c0 = serverNow()
	send(run, "RadiantHaloCharge", { Character = c, T0 = c0, Windup = windup })
	if not run.Sleep(windup) then return end
	send(run, "RadiantHaloStart", { Character = c, T0 = c0 + windup, Until = c0 + windup + dur })
	if not run.Sleep(HALO.LanceAt) then return end
	local cap, pct = H.HealCap or 60, H.HealPct or 1.0
	local healed, owed, n = 0, 0, 0
	lanceRun(run, HALO.LanceFor, function(dmg)
		local share = math.min(dmg * pct, cap - healed)
		if share <= 0 then return end
		healed += share
		owed += share
		n += 1
		if n % 2 == 0 then                                        -- RadiantHandler coalesces heals into ~0.35 s pops
			healPop(run, c, owed)
			owed = 0
		end
	end)
	if not run.Alive then return end
	if owed > 0 then healPop(run, c, owed) end
	if not run.Sleep(HALO.EndAfter) then return end
	run.Live[ending] = nil
	heldHaloEnd(held)                                            -- (the engraving fades with the End)
	send(run, "RadiantHaloEnd", { Character = c, Reason = "Expired" })
end

--- PASSIVE OVERFLOW LIGHT: a Blessing that runs its whole time (no ally on the aim line: the caster's own seal, no
--- Bond) lapses with its absorb untouched and pays out -- the seal contracts into the chest, the heal flare and sun
--- rosette, the motes, "+21" (Status.OnLapse: Absorb x ConvertPct)
local function overflowCast(run)
	local c = run.Caster
	local T = need("RadiantTuning")
	local O = (T and type(T.OverflowLight) == "table") and T.OverflowLight or {}
	pose(run, "RadiantBlessing")
	heldFlash(run, "blessing", "Blessing")                        -- (2026-10-26) the staff's one pulse
	run.Flag(c, true)
	send(run, "RadiantBlessing", { Character = c, Target = c, T0 = serverNow() })
	if not run.Sleep(OVERFLOW.Land) then return end
	popOn(c, Vector3.new(0, 1.2, 0), "BLESSED", "blessed")       -- StatusEffects' pop on the shielded body
	if not run.Sleep(OVERFLOW.At - OVERFLOW.Land) then return end
	local amount = absorb() * (O.ConvertPct or 0.6)
	-- RadiantHandler's RadiantOverflow: the recipient (its seal still up here, so the payoff runs on it)
	send(run, "RadiantOverflow", { Character = c, Amount = math.floor(amount + 0.5) })
	heldFlash(run, "overflow", "Overflow")                        -- (2026-10-26) the small flash on the caster's staff
	run.Flag(c, nil)                                              -- the status ran out with it
	healPop(run, c, amount)
end

----------------------------------------------------------------------------------------------------
local function entry(key, slot, cast, every)
	return {
		Key = key, Name = NAMES[slot], Slot = slot,
		Play = function(stage)
			local ok, stop = pcall(looped, stage, every, cast, key)
			if ok and type(stop) == "function" then return stop end
			warnOnce("play:" .. key, key .. ": " .. tostring(stop))
			return function() end
		end,
	}
end

return {
	Element = "Radiant",
	Moves = {
		entry("LightLance", "M1", lanceCast, LANCE.Every),
		entry("Blessing", "Primary", blessingCast, BLESS.Every),
		entry("PositionTrade", "Mobility", tradeCast, TRADE.Every),
		entry("Benediction", "Defense", beneCast, BENE.Every),
		entry("Halo", "Ultimate", haloCast, HALO.Every),
		entry("OverflowLight", "Passive", overflowCast, OVERFLOW.Every),
	},
}
