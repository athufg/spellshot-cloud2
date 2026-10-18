--[[
	RadiantAnim  (ModuleScript)  ->  ReplicatedStorage/IceMagic/RadiantAnim

	EVERY RADIANT ANIMATION AND THE STAFF PROP, and only that (Phase 5, 2026-09-29). Which clip plays on which body, on
	which clock; the staff in the right hold every frame; the staff's engraving glow. No VFX here (RadiantDraw draws
	those): the VFX reads the staff from here (StaffPoint / StaffLevel / PlantPoint).

	  BODY (third person, every Radiant character on every client): CastPose clips from RadiantPoseTable (registered
	    into CastPose.Clips at Start), played from the SERVER'S BROADCASTS, clocked from receipt x ShotTimeScale (the
	    UmbraAnim rule); the caster's own Light Lance, Blessing and Position Trade also from the keypress.
	    Every Radiant body RESTS on RadiantCarry (CastPose.SetBase): the staff upright in the right hand.
	  ARMS (first person, the local player): Viewmodel.Clips / ArmClips from RadiantPoseTable, from the KEYPRESS.
	  STAFF: one prop per Radiant character (IceMagicFX.RadiantStaffs), placed at RenderPriority Character+2 (after
	    CastPose at +1 and the Viewmodel at Camera+2), in the hold the clip's staff track names:
	      carry / press   grip in the right hand, the axis in the body frame     (1P: at the right fist, camera frame)
	      two_hand(_f)    grip in the right hand, the axis through the left hand (1P: right fist -> left fist)
	      raise / planted / pulled   upright, the butt Sink into the floor at the plant (1.7 right, 1.0 forward of
	                      the root, the floor under the server's At), lifted 0.936 / 0 / 0.986 (always the world staff)
	    The local player in first person gets a second, smaller staff (FirstPerson.Scale) on the viewmodel's fists. In the
	    carry and in Benediction's raise / planted / pulled it RIDES THE RIGHT FIST through FirstPerson.StaffInFist, the
	    right arm kept on the held arm shot RadiantStaffHold with its own small stride (2026-09-30: the owner, "holding
	    the staff in first person is weird"), so staff and hand move as one; this player's world staff is not drawn then.
	  GLOW: the Lines MeshPart through RadiantDraw.StaffGlow (idle #B9A46A SmoothPlastic .. Neon gold), per the owner's
	    rules: idle dim; Light Lance 0 -> 0.5 on the gather then 0.5 + 0.5 x Ramp^1.2 (the server's Ramp); Blessing one
	    pulse; Halo lit through the windup (-> 1 at the lock) and 0.6 for the window; Benediction lit while planted
	    (pulses flash on the server's pulse times); Position Trade a flash; Overflow a small flash on the caster's staff.
	  HALO'S SPIN (the two whole-body turns of the windup) is the one thing CastPose cannot key (its Turn is the torso on
	    the legs): RadiantAnim writes it on the R15 Root joint after CastPose has posed the body, and hands the joint
	    back the frame the spin is over (Config.HaloSpin = false drops it; the arms and the VFX spiral still play).
	  HALO'S FLOAT: while HaloUntil is set and the body is airborne, RadiantHaloFloat; on touchdown, RadiantHaloLand.

	WIRING (RadiantClient; nothing else changes):
	  RadiantAnim.Start()                        once, at RadiantClient's load (its own IceAbilityRemote listener)
	  RadiantAnim.LocalCast[id](character, role) id = Blessing | PositionTrade | Benediction | Halo: RadiantClient's
	                                             LocalCast entries call these (fill them at require: SpellshotInput
	                                             copies LocalCast once)
	  RadiantAnim.LanceBegin(character)          in FireM1, right after `lance = L` (the click the beam starts on)
	  RadiantAnim.LanceEnd(character)            in endLance (button up, server Off, death, no answer)
	Without the last two the own lance still animates, from the server's RadiantLanceOn / Off (a ping late).

	FOR THE VFX: StaffPoint(character, "tip"|"butt"|"grip"|"grip_front") -> Vector3?, StaffCFrame(character) -> CFrame?
	(the grip frame: +Y the long axis, LookVector the front face), StaffLevel(character) -> 0..1, PlantPoint(character)
	-> Vector3? (the butt's floor point while planted), SetStaffHidden(character, hidden).

	ASSETS: ReplicatedStorage.RadiantAssets.StaffA { Body, Lines } (MeshParts from staff_A_body.fbx / staff_A_lines.fbx;
	Config.AssetPaths also tries RadiantMeshes.StaffA and IceMagicMeshes.RadiantKit.StaffA). No staff asset: the clips
	and glow logic still run, no prop is drawn (warned once).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")

local RadiantAnim = {}
RadiantAnim.LocalCast = {}

local Config = {
	Element = "Radiant",
	AssetPaths = {
		{ "RadiantAssets", "StaffA" },
		{ "RadiantMeshes", "StaffA" },
		{ "IceMagicMeshes", "RadiantKit", "StaffA" },
	},
	StepName = "RadiantAnimStaff",
	StepPriority = Enum.RenderPriority.Character.Value + 2,
	HaloSpin = true,          -- the windup's two body spins on the Root joint
	HaloAirPose = true,       -- RadiantHaloFloat / RadiantHaloLand while airborne under the Halo
	FloatAfter = 0.12,        -- seconds airborne before the float pose (a step off a kerb is not a glide)
	ConfirmWait = 0.6,        -- own Halo / Benediction arms let go when no broadcast confirms within this + 2 x ping
	BaseEvery = 0.5,          -- re-assert SetBase this often (CastPose may drop and re-make a body's state)
	FPGripBack = 0.06,        -- 1P: the grip sits this far back from the arm's tip, inside the fist
	HoldShot = "RadiantStaffHold",   -- 1P: the right arm's held carry (Viewmodel.ArmClips, from RadiantPoseTable)
	FPHold = true,            -- false: no held carry (the first-person staff still rides the right fist)
}
RadiantAnim.Config = Config

----------------------------------------------------------------------------------------------------
-- modules, found lazily and guarded
----------------------------------------------------------------------------------------------------
local mods = {}
local function need(name)
	if mods[name] ~= nil then return mods[name] or nil end
	local m = iceFolder:FindFirstChild(name) or spellFolder:FindFirstChild(name)
	local ok, mod = pcall(function() return m and require(m) end)
	mods[name] = (ok and mod) or false
	if not ok then warn("[RadiantAnim] " .. name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[RadiantAnim] " .. tostring(msg))
end

local function timeScale()
	local v = iceFolder:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function ping()
	local ok, p = pcall(function() return player:GetNetworkPing() end)
	return ok and p or 0.1
end

----------------------------------------------------------------------------------------------------
-- curves (rad_anim's: ramp / env are sine in-out; key easings are Out, as CastPose's)
----------------------------------------------------------------------------------------------------
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

----------------------------------------------------------------------------------------------------
-- the table and the clips
----------------------------------------------------------------------------------------------------
local PT = nil
local function table_()
	if PT then return PT end
	PT = need("RadiantPoseTable")
	if not PT then warnOnce("pt", "RadiantPoseTable is missing: no Radiant animation will play") end
	return PT
end

local registered = false
local function register()
	if registered then return true end
	local P = table_()
	if not P then return false end
	local CP, VM = need("CastPose"), need("Viewmodel")
	if CP and CP.Clips then
		for name, clip in pairs(P.Clips) do CP.Clips[name] = CP.Clips[name] or clip end
	end
	if VM and VM.Clips and VM.ArmClips then
		for name, clip in pairs(P.Viewmodel.Clips) do VM.Clips[name] = VM.Clips[name] or clip end
		for name, clip in pairs(P.Viewmodel.ArmClips) do VM.ArmClips[name] = VM.ArmClips[name] or clip end
	end
	registered = true
	return true
end

local function isModel(x)
	return typeof(x) == "Instance" and x:IsA("Model")
end

local function bodyPlay(character, name, clock)
	if not (register() and isModel(character)) then return end
	local CP = need("CastPose")
	if not (CP and CP.Clips and CP.Clips[name]) then return end
	if clock then
		CP.PlayClocked(character, name, clock)
	else
		CP.Play(character, name)
	end
end

local function bodyCurrent(character)
	local CP = need("CastPose")
	return CP and isModel(character) and CP.CurrentClip(character) or nil
end

--- a clip of another kit is playing on this body (Radiant's own clips are all named Radiant*)
local function foreignClip(character)
	local cur = bodyCurrent(character)
	return cur ~= nil and string.sub(cur, 1, 7) ~= "Radiant"
end

local function bodyStopIf(character, name)
	local CP = need("CastPose")
	if CP and isModel(character) and CP.CurrentClip(character) == name then CP.Stop(character) end
end

local function vmPlay(name, clock)
	if not register() then return end
	local VM = need("Viewmodel")
	if VM and VM.Clips and VM.Clips[name] then
		-- the held carry is an arm SHOT, and a shot wins its arm over a clip: let go of it first (the step puts it back)
		if VM.StopShot then VM.StopShot("R", Config.HoldShot) end
		VM.Play(name, clock)
	end
end

local function vmStopIf(name)
	local VM = need("Viewmodel")
	if VM and VM.CurrentClip and VM.CurrentClip() == name then VM.Stop() end
end

local function vmShot(side, name)
	if not register() then return end
	local VM = need("Viewmodel")
	if VM and VM.ArmClips and VM.ArmClips[name] then VM.PlayShot(side, name) end
end

--- seconds since `start` (os.clock) on the clip clock (x ShotTimeScale), plus an offset
local function clockFrom(start, offset)
	offset = offset or 0
	return function()
		return (os.clock() - start) * timeScale() + offset
	end
end

----------------------------------------------------------------------------------------------------
-- the staff prop
----------------------------------------------------------------------------------------------------
local fxFolderCache = nil
local function fxFolder()
	if fxFolderCache and fxFolderCache.Parent then return fxFolderCache end
	local V = need("VFXLibrary")
	local name = V and V.Config and V.Config.FXFolderName or "IceMagicFX"
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	fxFolderCache = f
	return f
end

local function staffFolder()
	local fx = fxFolder()
	local f = fx:FindFirstChild("RadiantStaffs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "RadiantStaffs"
		f.Parent = fx
	end
	return f
end

local function findTemplate()
	for _, path in ipairs(Config.AssetPaths) do
		local node = ReplicatedStorage
		for _, n in ipairs(path) do
			node = node and node:FindFirstChild(n)
		end
		if node then
			local body, lines = node:FindFirstChild("Body"), node:FindFirstChild("Lines")
			if body and body:IsA("BasePart") and lines and lines:IsA("BasePart") then return body, lines end
		end
	end
	return nil, nil
end

local LINE_IDLE = Color3.fromRGB(185, 164, 106)
local GOLD = Color3.fromRGB(245, 194, 48)
local INLAY_HOT = Color3.fromRGB(255, 231, 160)

local Staff = {}
Staff.__index = Staff

local function newStaff(name, scale)
	local P = table_()
	local bodyT, linesT = findTemplate()
	if not (P and bodyT) then
		warnOnce("asset", "no staff asset at ReplicatedStorage.RadiantAssets.StaffA (Body + Lines): the staff is not drawn")
		return nil
	end
	local G = P.StaffGeometry
	local model = Instance.new("Model")
	model.Name = name
	local function prep(tpl, geo)
		local p = tpl:Clone()
		for _, d in ipairs(p:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Attachment") then d:Destroy() end
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		local ts = tpl:GetAttribute("TemplateSize")
		if typeof(ts) ~= "Vector3" then ts = geo.TemplateSize or tpl.Size end
		p.Size = ts * scale
		local ofp = tpl:GetAttribute("OriginFromPivot")
		if typeof(ofp) ~= "Vector3" then ofp = geo.OriginFromPivot end
		p.Parent = model
		return p, CFrame.new(-ofp * scale)
	end
	local body, bodyOfs = prep(bodyT, G.Body)
	local lines, linesOfs = prep(linesT, G.Lines)
	model.Parent = staffFolder()
	local s = setmetatable({
		Model = model, Body = body, BodyT = bodyT, LinesT = linesT, Lines = lines, BodyOfs = bodyOfs, LinesOfs = linesOfs, Scale = scale,
		Shown = true, Q = -1, Frame = nil,
	}, Staff)
	s:Glow(0)
	return s
end

function Staff:Place(S)
	self.Frame = S
	self.Body.CFrame = S * self.BodyOfs
	self.Lines.CFrame = S * self.LinesOfs
end

function Staff:Show(on)
	if on == self.Shown then return end
	self.Shown = on
	local tr = on and 0 or 1
	self.Body.Transparency = tr
	self.Lines.Transparency = tr
end

--- the engraving at a glow level: RadiantDraw.StaffGlow (the kit's staff_glow), or the same look here without it
-- THE STAFF BODY UNDER A SKIN (2026-10-10): its colour is baked vertex colour, so a skin recolours the mesh itself --
-- once per client per skin, off the render loop -- into the palette along the staff's length, keeping the baked light and
-- shadow, and MeshPart:ApplyMesh puts it on; Default puts the original back. Needs the experience's "Allow Mesh / Image
-- APIs" (Security); without it the body simply stays as it is. Colour only: no part is added.
local skinBodies = {}          -- [skinId] = recoloured MeshPart | "building" | false (failed)
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
		if not ok then warn("[RadiantAnim] skinned staff body: " .. tostring(mp)) end
	end)
	return nil
end

-- THE DEVIL SKIN'S STAFF (2026-10-13): the devil trident from RadiantDevilStaffData, built once per client off the render
-- loop (EditableMesh -> a fixed copy -> MeshPart, flat-shaded, its baked corner colours), put on Body and Lines with its
-- own size and offset; the staff's tip point moves up with it (Light Lance fires from the trident's centre tip).
local devilStaff = nil         -- { Body, BodyC, BodySize, Lines, LinesC, LinesSize, Tip } | "building" | false
-- THE FIRST-PERSON TRIDENT (owner, 2026-10-13: "bigger and lowered"): at StaffA's 0.6 its head ran off the top of the
-- screen. The own first-person copy is drawn at 0.75 and slid 1.9 staff studs down through the hand, so the whole head
-- sits just under the top edge; the arms and poses are untouched, and the world trident others see is as built.
local DEVIL_FP = { Scale = 0.75, Slide = 1.9 }
-- THE THIRD-PERSON TRIDENT (owner, 2026-10-13: "almost touching the ground"): held at its grip, the butt hung 0.84 studs
-- above the floor in carry and walk (the carry holds it rigid). It is slid 0.72 down through the hand, the butt ~0.12
-- off the floor; the head comes down with it. (In the Benediction plant it sinks that much deeper into the ground.)
local DEVIL_TP_SLIDE = 0.72
local SMOOTH_HEAD_FROM, SMOOTH_COS = 3.1, math.cos(math.rad(65))   -- the head: above the collar (staff studs)
--- recol(colour, u) (optional): the corner colours recoloured by their height u (0 butt .. 1 tip) -- a wrap over the skin
local function buildDevilPart(d, smoothFrom, recol)
	local AS = game:GetService("AssetService")
	local em = AS:CreateEditableMesh()
	local P, vids, pos = d.P, {}, {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 1, #P, 3 do
		local v = Vector3.new(P[i], P[i + 1], P[i + 2])
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
	-- (2026-10-13, owner: "smooth glossy head") above smoothFrom the head is shaded smooth across its rounded edges (the
	-- neighbouring face normals under SMOOTH_COS apart, area-weighted), so its tubes catch a glossy highlight like the
	-- Blender render; the blades' sharp edges stay hard, and the shaft stays faceted like the rest of the kit
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
			em:SetFaceNormals(f, { nid, nid, nid })          -- faceted, like the rest of the kit
		end
		if cols then em:SetFaceColors(f, { colId(TC[t], pos[a].Y), colId(TC[t + 1], pos[b].Y), colId(TC[t + 2], pos[c].Y) }) end
	end
	local fixed = AS:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	em:Destroy()
	return AS:CreateMeshPartAsync(Content.fromObject(fixed)), (lo + hi) / 2, hi - lo
end

-- A WRAP OVER THE SKIN (2026-10-14): the trident rebuilt once per client per wrap from a plain base -- its body in the
-- wrap's colours along its length at full strength, like StaffA under a wrap (owner: none of the devil's dark iron)
local devilWrapped = {}        -- [palette Key] = { Body, ... } | "building" | false
local function wrapTone(_c, w)
	return w
end

local function getDevilStaff(pal)
	if pal and pal.Wrap and pal.At then
		local key = pal.Key or pal.Wrap
		local got = devilWrapped[key]
		if got ~= nil then return (got ~= "building" and got) or nil end
		local D = need("RadiantDevilStaffData")
		if not D then
			devilWrapped[key] = false
			return nil
		end
		devilWrapped[key] = "building"
		task.spawn(function()
			local ok, res = pcall(function()
				local recol = function(c, u) return wrapTone(c, pal.At(u)) end
				local b, bc, bs = buildDevilPart(D.Body, SMOOTH_HEAD_FROM, recol)
				local l, lc, ls = buildDevilPart(D.Lines)
				return { Body = b, BodyC = bc, BodySize = bs, Lines = l, LinesC = lc, LinesSize = ls, Tip = D.Tip }
			end)
			devilWrapped[key] = ok and res or false
			if not ok then warn("[RadiantAnim] wrapped devil staff: " .. tostring(res)) end
		end)
		return nil
	end
	if devilStaff ~= nil then return (devilStaff ~= "building" and devilStaff) or nil end
	local D = need("RadiantDevilStaffData")
	if not D then
		devilStaff = false
		return nil
	end
	devilStaff = "building"
	task.spawn(function()
		local ok, res = pcall(function()
			local b, bc, bs = buildDevilPart(D.Body, SMOOTH_HEAD_FROM)
			local l, lc, ls = buildDevilPart(D.Lines)
			return { Body = b, BodyC = bc, BodySize = bs, Lines = l, LinesC = lc, LinesSize = ls, Tip = D.Tip }
		end)
		devilStaff = ok and res or false
		if not ok then warn("[RadiantAnim] devil staff: " .. tostring(res)) end
	end)
	return nil
end

--- Put the devil trident on (dv) or StaffA back (nil): the meshes, their sizes and their offsets from the staff frame.
function Staff:UseDevil(dv)
	if dv and not self.Orig then
		self.Orig = { BodySize = self.Body.Size, BodyOfs = self.BodyOfs, LinesSize = self.Lines.Size, LinesOfs = self.LinesOfs }
	end
	if dv then
		pcall(function() self.Body:ApplyMesh(dv.Body) end)
		pcall(function() self.Lines:ApplyMesh(dv.Lines) end)
		-- the first-person copy is bigger and slid down through the hand (DEVIL_FP); the world one is as built
		local sc, sl = self.Scale * (self.DevilK or 1), Vector3.new(0, self.DevilSlide or 0, 0)
		self.Body.Size, self.BodyOfs = dv.BodySize * sc, CFrame.new((dv.BodyC - sl) * sc)
		self.Lines.Size, self.LinesOfs = dv.LinesSize * sc, CFrame.new((dv.LinesC - sl) * sc)
	elseif self.Devil and self.Orig then
		pcall(function() self.Body:ApplyMesh(self.BodyT) end)
		if self.LinesT then pcall(function() self.Lines:ApplyMesh(self.LinesT) end) end
		self.Body.Size, self.BodyOfs = self.Orig.BodySize, self.Orig.BodyOfs
		self.Lines.Size, self.LinesOfs = self.Orig.LinesSize, self.Orig.LinesOfs
	end
	self.Devil = dv
	if self.Frame then self:Place(self.Frame) end
end

function Staff:Glow(level)
	local q = math.floor(clamp01(level) * 128 + 0.5)
	-- a skin (SkinCatalog: its owner's Light Lance skin, the staff being the M1's own) colours the engraving and the body
	local S = need("SkinCatalog")
	local pal = S and self.Owner and S.Resolve("Radiant", "LightLance", S.Chosen(self.Owner, "LightLance")) or nil
	local want = pal and (pal.Key or pal.Id) or "Default"       -- (a wrap over the skin: its own trident build)
	if self.BodySkin ~= want and self.BodyT and pal and pal.Staff == "Devil" then
		local dv = getDevilStaff(pal)
		if dv then
			self.BodySkin = want
			self:UseDevil(dv)
		end
	elseif self.BodySkin ~= want and self.BodyT then
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
	if key == self.Q and pal == self.QPal then return end   -- (the palette too: a wrap put on over a skin keeps the level)
	self.Q, self.QPal = key, pal
	local RD = need("RadiantDraw")
	if RD and type(RD.StaffGlow) == "function" then
		local ok = pcall(RD.StaffGlow, { self.Lines }, q / 128, pal)
		if ok then return end
	end
	local l = q / 128
	self.Lines.Material = l >= 0.25 and Enum.Material.Neon or Enum.Material.SmoothPlastic
	self.Lines.Color = l <= 0.5 and LINE_IDLE:Lerp(GOLD, l / 0.5) or GOLD:Lerp(INLAY_HOT, (l - 0.5) / 0.5)
end

function Staff:Point(name)
	local P = table_()
	if not (self.Frame and P) then return nil end
	local G = P.StaffGeometry
	local v = (name == "tip" and ((self.Devil and self.Devil.Tip) or G.Tip)) or (name == "butt" and G.Butt)
		or (name == "grip_front" and G.GripFront)
		or Vector3.zero
	if self.Devil and v ~= Vector3.zero then   -- the first-person trident's size and slide (UseDevil); the grip stays put
		return self.Frame:PointToWorldSpace((v - Vector3.new(0, self.DevilSlide or 0, 0)) * self.Scale * (self.DevilK or 1))
	end
	return self.Frame:PointToWorldSpace(v * self.Scale)
end

function Staff:Destroy()
	self.Model:Destroy()
end

----------------------------------------------------------------------------------------------------
-- hold frames. A staff frame: position = the main grip, UpVector = the long axis, LookVector = the front face.
----------------------------------------------------------------------------------------------------
--- the axis along `axis`, the front face toward `front` (rad_anim._orient)
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

--- the kit's two_hand (rad_anim.set_staff): Blender staff +X toward world up, i.e. the part's -X toward up
local function frameAxisUp(grip, axis)
	local y = axis.Unit
	local upP = Vector3.yAxis - y * y.Y
	if upP.Magnitude < 1e-4 then return frameAxisFront(grip, y, -Vector3.zAxis) end
	local x = -upP.Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(grip, x, y, z)
end

--- the body's yaw-only frame (rad_anim.body_basis): the torso's heading, so it carries Halo's spin and the Turn
local function bodyBasis(S)
	local ut = S.UpperTorso
	local look = ut and ut.Parent and ut.CFrame.LookVector or S.Root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then flat = S.Root.CFrame.LookVector * Vector3.new(1, 0, 1) end
	if flat.Magnitude < 1e-3 then flat = -Vector3.zAxis end
	local p = S.Root.Position
	return CFrame.lookAt(p, p + flat.Unit)
end

local function handGrip(S, side)
	local P = table_()
	local hand = side == "L" and S.LeftHand or S.RightHand
	if not (hand and hand.Parent and P) then return nil end
	return hand.CFrame:PointToWorldSpace(P.StaffGeometry.GripOnHand)
end

local WORLD = { raise = true, planted = true, pulled = true }

local function plantFrame(S, mode, basis)
	local P = table_()
	local pl = S.Plant
	if not (pl and P) then return nil end
	local G = P.StaffGeometry
	-- the plant point is fixed in the world when the channel starts (pl.Point, 2026-09-30): a caster who turns (a
	-- first-person camera turns the body) no longer swings the planted staff round with them
	local at = pl.Point or (S.Root.Position + basis:VectorToWorldSpace(G.PlantOffset))
	local lift = (mode == "raise" and G.RaiseLift) or (mode == "pulled" and G.PullLift) or 0
	local buttY = pl.FloorY - G.Sink + lift
	return frameAxisFront(Vector3.new(at.X, buttY - G.Butt.Y, at.Z), Vector3.yAxis, pl.Look or basis.LookVector)
end

local function bodyFrame(S, mode, basis)
	local P = table_()
	if not P then return nil end
	local G = P.StaffGeometry
	if WORLD[mode] then return plantFrame(S, mode, basis) end
	local gr = handGrip(S, "R")
	if not gr then return nil end
	if mode == "two_hand" or mode == "two_hand_f" then
		local gl = handGrip(S, "L")
		local ax = gl and (gl - gr) or basis.LookVector
		if ax.Magnitude < 0.05 then ax = basis.LookVector end
		if mode == "two_hand" then return frameAxisUp(gr, ax) end
		return frameAxisFront(gr, ax, basis.LookVector)
	end
	local ax = basis:VectorToWorldSpace(mode == "press" and G.PressAxis or G.CarryAxis)
	return frameAxisFront(gr, ax, basis.LookVector)
end

--- first person: the viewmodel's fists (nil in the third-person view or with no rig)
local function fpFrame(mode)
	local P, VM = table_(), need("Viewmodel")
	if not (P and VM and VM.GetFistCFrame) then return nil end
	local fr = VM.GetFistCFrame("R")
	if not fr then return nil end
	local cam = workspace.CurrentCamera.CFrame
	local grip = fr.Position - fr.LookVector * Config.FPGripBack
	-- the engraved front face toward the player: toward the lens for an upright staff, on top for one along the view
	local front = -cam.LookVector + cam.UpVector * 1.5
	if mode == "two_hand" or mode == "two_hand_f" then
		local fl = VM.GetFistCFrame("L")
		local ax = fl and ((fl.Position - fl.LookVector * Config.FPGripBack) - grip) or cam.LookVector
		if ax.Magnitude < 0.05 then ax = cam.LookVector end
		return frameAxisFront(grip, ax, front)
	end
	local FP = P.FirstPerson
	if mode == "press" or typeof(FP.StaffInFist) ~= "CFrame" then
		local ax = cam:VectorToWorldSpace(mode == "press" and FP.PressAxis or FP.CarryAxis)
		return frameAxisFront(grip, ax, front)
	end
	-- the carry and Benediction's raise / planted / pulled (2026-09-30): the staff RIDES THE RIGHT FIST through one fixed
	-- transform, so whatever moves the fist (the hold's stride and sway, the Benediction keys) moves the staff with it.
	-- It was the fist's POSITION with a camera-fixed axis leaning into the scene: the staff slid through a hand that
	-- swung under it, and dived off the frame with the sprint stride.
	return fr * FP.StaffInFist
end

--- the staff's hold now: modeA, and (modeB, u) while a segment blends modeA -> modeB
local function holdNow(S)
	local tr = S.Track
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
	if last.Mode == "carry" and not tr.Hold then S.Track = nil end
	return last.Mode
end

local function setTrack(S, name, clock, hold)
	local P = table_()
	local segs = P and P.Staff[name]
	if not segs then return end
	S.Track = { Name = name, Segs = segs, Clock = clock, Hold = hold }
end

--- let go of a held track: blend from its hold back to the carry
local function releaseTrack(S, name)
	local P = table_()
	local r = P and P.StaffRelease[name]
	if not (S.Track and S.Track.Name == name) then return end
	if not r then
		S.Track = nil
		return
	end
	S.Track = { Name = name .. "_Release", Segs = { { T0 = 0, T1 = r.Dur, Mode = "carry", From = r.From, Ease = r.Ease } },
		Clock = clockFrom(os.clock()) }
end

----------------------------------------------------------------------------------------------------
-- per character
----------------------------------------------------------------------------------------------------
local chars = {}               -- [character] = S
local fp = nil                 -- the local player's first-person staff: { Staff }
local ownCast = {}             -- [ability id] = os.clock() of this client's own keypress
local lanceHooked = false      -- RadiantClient calls LanceBegin / LanceEnd: the own lance ignores its broadcasts
local stepBound = false
local ensureBound

local function isRadiant(plr)
	return plr ~= nil and plr:GetAttribute("Element") == Config.Element
end

local function rootJoint(character)
	local lt = character:FindFirstChild("LowerTorso")
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

--- hand the Root joint back (the spin wrote it last)
local function endSpin(S)
	local sp = S.Spin
	S.Spin = nil
	if not (sp and sp.Inst and sp.Inst.Parent and sp.Last and sp.Base) then return end
	local ok, cur = pcall(function() return sp.Inst[sp.Prop] end)
	if ok and near(cur, sp.Last) then sp.Inst[sp.Prop] = sp.Base end
end

local function refreshParts(S)
	local c = S.Character
	S.Humanoid = c:FindFirstChildOfClass("Humanoid")
	S.Root = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
	S.UpperTorso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
	S.RightHand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	S.LeftHand = c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm")
end

local function dropStaffs(S)
	if S.Staff then
		S.Staff:Destroy()
		S.Staff = nil
	end
	if S.Player == player and fp then
		fp.Staff:Destroy()
		fp = nil
	end
end

local function cleanup(character)
	local S = chars[character]
	if not S then return end
	chars[character] = nil
	endSpin(S)
	dropStaffs(S)
	if S.BaseSet then
		local CP = need("CastPose")
		if CP and character.Parent then pcall(CP.SetBase, character, nil) end
	end
	for _, cn in ipairs(S.Conns) do cn:Disconnect() end
end

local function stateOf(character)
	if not isModel(character) then return nil end
	local S = chars[character]
	if S then return S end
	if not character.Parent then return nil end
	S = { Character = character, Player = Players:GetPlayerFromCharacter(character), Glows = {}, Conns = {},
		Level = 0, HiddenBy = {}, BaseAt = 0 }
	refreshParts(S)
	if not (S.Humanoid and S.Root) then return nil end
	chars[character] = S
	S.Conns[#S.Conns + 1] = S.Humanoid.Died:Connect(function() cleanup(character) end)
	S.Conns[#S.Conns + 1] = character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then cleanup(character) end
	end)
	S.Conns[#S.Conns + 1] = character.ChildAdded:Connect(function() refreshParts(S) end)
	ensureBound()
	return S
end

--- the Element decides the staff and the carry; a character without it keeps only its clips (a Technique slotted by
--- another Element plays Benediction's or Position Trade's body with no staff)
local function refresh(plr)
	local c = plr and plr.Character
	if not c then return end
	local S = stateOf(c)
	if not S then return end
	local radiant = isRadiant(plr) and S.Humanoid.Health > 0
	S.Radiant = radiant
	if radiant then
		register()
		if not S.Staff then
			S.Staff = newStaff("RadiantStaff_" .. plr.Name, 1)
			if S.Staff then
				S.Staff.Owner = plr
				S.Staff.DevilSlide = DEVIL_TP_SLIDE
			end
		end
		if plr == player and not fp then
			local P = table_()
			local st = P and newStaff("RadiantStaff_FirstPerson", P.FirstPerson.Scale)
			if st then
				st.Owner = plr
				st.DevilK, st.DevilSlide = DEVIL_FP.Scale / P.FirstPerson.Scale, DEVIL_FP.Slide
				fp = { Staff = st }
			end
		end
		S.BaseAt = 0                                   -- the step sets the base
	else
		dropStaffs(S)
		if S.BaseSet then
			local CP = need("CastPose")
			if CP then pcall(CP.SetBase, c, nil) end
			S.BaseSet = false
		end
		S.Track, S.Plant = nil, nil
		table.clear(S.Glows)
	end
end

----------------------------------------------------------------------------------------------------
-- glow sources: fn(now) -> level | nil (done); the staff shows the brightest
----------------------------------------------------------------------------------------------------
local function glowOn(S, key, fn)
	S.Glows[key] = fn
end

local function glowLevel(S, now)
	local best = 0
	for key, fn in pairs(S.Glows) do
		local ok, l = pcall(fn, now)
		if not ok or l == nil then
			S.Glows[key] = nil
		elseif l > best then
			best = l
		end
	end
	return best
end

--- a one-shot envelope from `start` (os.clock): env over {t0, t1, fin, fout} on the clip clock
local function envGlow(start, spec, offset)
	return function(now)
		local e = (now - start) * timeScale() + (offset or 0)
		if e >= spec[2] then return nil end
		return env(e, spec[1], spec[2], spec[3], spec[4])
	end
end

----------------------------------------------------------------------------------------------------
-- LIGHT LANCE
----------------------------------------------------------------------------------------------------
local function lanceBegin(c, id)
	local S = stateOf(c)
	if not S then return end
	if S.Lance and not S.Lance.ReleasedAt then return end
	if id ~= nil and id == S.LanceDone then return end        -- a late tick about the beam that just ended
	local P = table_()
	if not P then return end
	local L = { Start = os.clock(), Ramp = 0, Level = 0, Id = id }
	S.Lance = L
	local TL = P.Timing.Lance
	bodyPlay(c, "RadiantLance")
	if c == player.Character then vmPlay("RadiantLance") end
	setTrack(S, "RadiantLance", clockFrom(L.Start), true)
	glowOn(S, "lance", function(now)
		if S.Lance ~= L then return nil end
		if L.ReleasedAt then
			local e = (now - L.ReleasedAt) * timeScale()
			if e >= TL.ReleaseFade then
				S.Lance = nil
				return nil
			end
			return L.Level * (1 - ramp(e, 0, TL.ReleaseFade))
		end
		local e = (now - L.Start) * timeScale()
		local g = 0.5 * ramp(e, TL.GlowFrom, TL.GlowRamp)
		if e >= TL.Fire then g = math.max(g, 0.5 + 0.5 * clamp01(L.Ramp) ^ 1.2) end
		L.Level = g
		return g
	end)
end

local function lanceEnd(c)
	local S = chars[c]
	if c == player.Character then vmStopIf("RadiantLance") end
	bodyStopIf(c, "RadiantLance")
	if not S then return end
	if S.Lance and not S.Lance.ReleasedAt then
		S.Lance.ReleasedAt = os.clock()
		S.LanceDone = S.Lance.Id
	end
	releaseTrack(S, "RadiantLance")
end

function RadiantAnim.LanceBegin(character)
	lanceHooked = true
	lanceBegin(character)
end

function RadiantAnim.LanceEnd(character)
	lanceHooked = true
	lanceEnd(character)
end

----------------------------------------------------------------------------------------------------
-- HALO
----------------------------------------------------------------------------------------------------
--- the windup clock: the payload's (real) Windup maps onto the authored 0..0.9, the rest runs at the clip rate
local function haloClock(start, windup)
	local P = table_()
	local lock = P and P.Timing.Halo.Lock or 0.9
	local w = math.max(0.05, tonumber(windup) or lock)
	return function()
		local e = os.clock() - start
		if e <= w then return lock * e / w end
		return lock + (e - w) * timeScale()
	end
end

local function spinStart(S, clock)
	local P = table_()
	if not (Config.HaloSpin and P and P.Spin.RadiantHaloWindup) then return end
	endSpin(S)
	local inst, prop = rootJoint(S.Character)
	if not inst then return end
	S.Spin = { Track = P.Spin.RadiantHaloWindup, Clock = clock, Inst = inst, Prop = prop, Clip = "RadiantHaloWindup" }
end

local function sampleSpin(track, t)
	if t < track[1].t then return track[1].Deg end
	local last = track[#track]
	if t >= last.t then return nil end
	for i = 1, #track - 1 do
		local a, b = track[i], track[i + 1]
		if t <= b.t then
			local u = (t - a.t) / math.max(1e-4, b.t - a.t)
			local e = TweenService:GetValue(clamp01(u), b.Easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			return a.Deg + (b.Deg - a.Deg) * e
		end
	end
	return nil
end

local function spinStep(S)
	local sp = S.Spin
	if not sp then return end
	if not (sp.Inst and sp.Inst.Parent) then
		S.Spin = nil
		return
	end
	local deg = sampleSpin(sp.Track, sp.Clock())
	local live = deg ~= nil and bodyCurrent(S.Character) == sp.Clip
	local cur = sp.Inst[sp.Prop]
	-- unchanged since our last write: nobody else wrote the joint this frame, so its own value is the one we kept;
	-- changed: CastPose (a Drop) or the rig wrote it, and that is the base the spin goes on
	local base = (sp.Last and near(cur, sp.Last)) and sp.Base or cur
	sp.Base = base
	if live and deg then
		local w = base * CFrame.Angles(0, math.rad(deg :: number), 0)
		sp.Inst[sp.Prop] = w
		sp.Last = w
	else
		endSpin(S)
	end
end

--- withClips false: the window only (no windup seen: joined late, or a zero windup), the clock already past the lock
local function haloBegin(c, windup, withClips)
	local S = stateOf(c)
	local P = table_()
	if not (S and P) then return end
	local start = os.clock()
	local clock = haloClock(start, windup)
	if not withClips then
		local lock = P.Timing.Halo.Lock
		clock = function() return lock + 1 + (os.clock() - start) * timeScale() end
	end
	local H = { Clock = clock, Level = 0, Start = start }
	S.Halo = H
	if withClips then
		bodyPlay(c, "RadiantHaloWindup", clock)
		spinStart(S, clock)
		if S.Radiant then setTrack(S, "RadiantHaloWindup", clock, false) end
	end
	local TH = P.Timing.Halo
	glowOn(S, "halo", function(now)
		if S.Halo ~= H then return nil end
		if H.EndedAt then
			local e = (now - H.EndedAt) * timeScale()
			if e >= TH.EndFade then
				S.Halo = nil
				return nil
			end
			return H.EndLevel * (1 - ramp(e, 0, TH.EndFade))
		end
		local t = H.Clock()
		local g = ramp(t, 0, TH.Lock) - (1 - TH.Window) * ramp(t, TH.DimFrom, TH.DimFor)
		H.Level = g
		return g
	end)
end

local function haloEnd(c, cancelled)
	local S = chars[c]
	if not S then return end
	local H = S.Halo
	if H and not H.EndedAt then
		H.EndedAt = os.clock()
		H.EndLevel = H.Level
	end
	if cancelled then
		endSpin(S)
		bodyStopIf(c, "RadiantHaloWindup")
		if c == player.Character then vmStopIf("RadiantHaloWindup") end
		if S.Track and S.Track.Name == "RadiantHaloWindup" then
			S.Track = { Name = "HaloCancel", Segs = { { T0 = 0, T1 = 0.3, Mode = "carry", From = "two_hand_f",
				Ease = "Sine" } }, Clock = clockFrom(os.clock()) }
		end
	end
	if S.Floating then
		S.Floating = false
		bodyStopIf(c, "RadiantHaloFloat")
	end
end

--- the float: airborne under the Halo -> the glide pose; touchdown -> the landing
local function airStep(S, now)
	if not Config.HaloAirPose then return end
	local c = S.Character
	local halo = c:GetAttribute("HaloUntil") ~= nil
	if not halo then
		S.AirSince = nil
		if S.Floating then
			S.Floating = false
			bodyStopIf(c, "RadiantHaloFloat")
		end
		return
	end
	local root, hum = S.Root, S.Humanoid
	local reach = (hum.HipHeight or 2) + root.Size.Y * 0.5 + 0.6
	local params = S.AirParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		S.AirParams = params
	end
	local fx, cam = fxFolder(), workspace.CurrentCamera
	if S.AirFx ~= fx or S.AirCam ~= cam then            -- the filter list: built once, again only if these change
		S.AirFx, S.AirCam = fx, cam
		params.FilterDescendantsInstances = { c, fx, cam }
	end
	local airborne = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params) == nil
	local cur = bodyCurrent(c)
	if airborne then
		S.AirSince = S.AirSince or now
		if not S.Floating and cur == nil and now - S.AirSince >= Config.FloatAfter then
			S.Floating = true
			bodyPlay(c, "RadiantHaloFloat")
		end
	else
		S.AirSince = nil
		if S.Floating then
			S.Floating = false
			if cur == "RadiantHaloFloat" then bodyPlay(c, "RadiantHaloLand") end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- BENEDICTION
----------------------------------------------------------------------------------------------------
local function floorUnder(S, at)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { fxFolder(), workspace.CurrentCamera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then ex[#ex + 1] = p.Character end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(at, Vector3.new(0, -12, 0), params)
	if hit then return hit.Position.Y end
	local base = S.Character:GetAttribute("BaseHipHeight") or S.Humanoid.HipHeight
	return at.Y - (base + S.Root.Size.Y * 0.5)
end

--- the kneel's clock, on the SERVER's clock (review fix 2026-09-29): the plant key (Timing.Benediction.Plant) lands at
--- the server's T0, the instant RadiantFX_Staff draws the impact (its clip 0.44 = T0), so a late receipt starts part-way
--- into the drive (CastPose eases in at Rate 40). Sits on the last kneel key until the End, then plays the rise.
--- 2026-09-30: the channel is HELD (open until the End) and the wind-up is slower: T0 is the server's PLANT (press +
--- WindUp), and the payload's WindUp (real s) maps onto the authored 0..Plant, so a retuned WindUp needs no new table.
--- A missed End: no pulse for Every + Timeout past the last one (or the plant) lets go by itself. That let-go is
--- PROVISIONAL (2026-09-30 review): B.TimedOut, and a pulse after it starts the kneel again (H.RadiantBenedictionPulse).
local function benClock(S, B)
	local P = table_()
	local TB = P and P.Timing.Benediction
	local hold = TB and TB.Hold or 2.52
	local plant = TB and TB.Plant or 0.5
	return function()
		if B.EndAt then return hold + (os.clock() - B.EndAt) * timeScale() end
		local sn = serverNow()
		if sn > (B.LastPulse or B.T0) + B.Every + B.Timeout then
			B.EndAt, B.TimedOut = os.clock(), true
			return hold
		end
		local r = (sn - B.T0) * timeScale()                  -- clip seconds from the plant (negative in the wind-up)
		local c
		if r >= 0 then
			c = plant + r
		else
			local w = (B.WindUp and B.WindUp > 0) and B.WindUp * timeScale() or plant
			c = plant + r * plant / w
		end
		return math.clamp(c, 0, hold)
	end
end

--- `resumeAt` (server time): a channel that timed out on this client and is still running on the server (a pulse came
--- after the let-go) starts again on the same Start, its missed-End clock counting from that pulse.
local function benBegin(c, d, resumeAt)
	local S = stateOf(c)
	local P = table_()
	if not (S and P) then return end
	local TB = P.Timing.Benediction
	local Tn = need("RadiantTuning")
	local TnB = (Tn and type(Tn.Benediction) == "table") and Tn.Benediction or {}
	local B = { Level = 0, T0 = type(d.T0) == "number" and d.T0 or serverNow(), StartedAt = os.clock(),
		WindUp = type(d.WindUp) == "number" and d.WindUp or nil,
		Every = (type(d.Every) == "number" and d.Every > 0) and d.Every or ((TnB.PulseEvery or 0.5) / timeScale()),
		Timeout = TnB.EndTimeout or 1.5, Start = d, LastPulse = resumeAt }
	B.Clock = benClock(S, B)
	S.Ben, S.BenLast = B, B
	if not (resumeAt and S.Plant) then                   -- a resumed channel keeps its staff where it was planted
		local at = typeof(d.At) == "Vector3" and d.At or S.Root.Position
		local basis = bodyBasis(S)
		S.Plant = { FloorY = floorUnder(S, at), At = at, Look = basis.LookVector,
			Point = at + basis:VectorToWorldSpace(P.StaffGeometry.PlantOffset) }
	end
	bodyPlay(c, "RadiantBenediction", B.Clock)
	if c == player.Character and not (ownCast.Benediction and os.clock() - ownCast.Benediction < 1.5) then
		vmPlay("RadiantBenediction", B.Clock)
	end
	if S.Radiant then setTrack(S, "RadiantBenediction", B.Clock, false) end
	glowOn(S, "benediction", function(now)
		if S.Ben ~= B then return nil end
		if B.EndAt and B.EndLevel then
			local e = (now - B.EndAt) * timeScale()
			if e >= TB.EndFade then
				S.Ben = nil
				return nil
			end
			return B.EndLevel * (1 - ramp(e, 0, TB.EndFade))
		end
		local t = B.Clock()
		local g
		if t < TB.Plant then
			g = TB.PreGlow * ramp(t, 0, TB.Plant)
		else
			g = 1 - (1 - TB.Floor) * ramp(t, TB.Settle[1], TB.Settle[2])
			-- a pulse every Every from the plant for as long as the channel is held: the two nearest now
			local sn, pe, pl = serverNow(), 0, TB.Pulse
			local k0 = math.floor((sn - B.T0) / B.Every)
			for k = math.max(1, k0), k0 + 1 do
				local ta = B.T0 + k * B.Every
				pe = math.max(pe, env(sn, ta + pl[1], ta + pl[2], pl[3], pl[4]))
			end
			g = math.max(g, TB.Floor + (1 - TB.Floor) * pe)
		end
		B.Level = g
		if B.EndAt then B.EndLevel = g end                 -- the End arrived: fade from this frame's level
		return g
	end)
end

local function benEnd(c)
	local S = chars[c]
	if not S then return end
	local B = S.Ben
	if B and not B.EndAt then B.EndAt = os.clock() end
end

----------------------------------------------------------------------------------------------------
-- the frame: spin, air, staff, glow
----------------------------------------------------------------------------------------------------
local function lerpFrame(a, b, u)
	if not a then return b end
	if not b then return a end
	return a:Lerp(b, u)
end

local function handVisible(S)
	local h = S.RightHand
	if not (h and h.Parent) then return false end
	return h.Transparency < 0.99 and h.LocalTransparencyModifier < 0.99
end

local function hiddenByCaller(S)
	return next(S.HiddenBy) ~= nil
end

----------------------------------------------------------------------------------------------------
-- THE FIRST-PERSON HOLD (2026-09-30): the right arm on a held arm shot whenever nothing else has it, with its own stride
----------------------------------------------------------------------------------------------------
-- The rig's walk is its Sprint state (MovementController auto-sprints): the RIVALS stride swings the right arm +-30 deg
-- and drops it off the frame, which is what the staff was riding. A held shot fades the rig's stride, fall lift and
-- look-sway off that arm (Viewmodel.Update), so the hold carries its own, small: Aqua's gun hold, one arm.
local hold = { On = false, Offset = false, Rig = nil, Phase = 0, Amt = 0, SwayX = 0, SwayY = 0, LastCam = nil, LastAt = nil }

local function otherShotOnR(VM)
	for name in pairs(VM.ArmClips) do
		if name ~= Config.HoldShot and VM.ShotPlaying("R", name) then return true end
	end
	return false
end

--- Viewmodel.SetArmOffset("R") while the hold is on: the look-sway (the rig's own constants and formula) and a stride
--- bob on the feet; nil otherwise. Runs inside Viewmodel.Update; never yields. The delta is ONE table, rewritten every
--- frame (2026-09-30 review: no per-frame garbage): Viewmodel's withArmOffset only reads it.
local holdDelta = { X = 0, Y = 0 }
local function holdOffset()
	if not hold.On then
		hold.LastCam, hold.LastAt = nil, nil
		return nil
	end
	local now = os.clock()
	local dt = hold.LastAt and math.clamp(now - hold.LastAt, 0, 0.1) or 0
	hold.LastAt = now
	local P, VM = table_(), need("Viewmodel")
	local VC = VM and VM.Config
	local Bb = P and P.FirstPerson and P.FirstPerson.Bob
	if not (Bb and VC) then return nil end
	local cam = workspace.CurrentCamera
	local camCF = cam and cam.CFrame
	if camCF and hold.LastCam then
		local _, dy, dx = hold.LastCam:ToObjectSpace(camCF):ToEulerAnglesYXZ()
		hold.SwayX = math.clamp(hold.SwayX + (-dy * VC.SwayAmount * 60 - hold.SwayX) * VC.SwayResponse, -VC.SwayMax, VC.SwayMax)
		hold.SwayY = math.clamp(hold.SwayY + (-dx * VC.SwayAmount * 60 - hold.SwayY) * VC.SwayResponse, -VC.SwayMax, VC.SwayMax)
	end
	hold.LastCam = camCF
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local v = root and root.AssemblyLinearVelocity or Vector3.zero
	local st = hum and hum:GetState()
	local air = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
	local sliding = c ~= nil and c:GetAttribute("MoveState") == "Slide"
	-- on the feet, moving, not sliding (root velocity: MoveDirection reads 0 in a render step)
	local goal = (not air and not sliding) and math.clamp((Vector3.new(v.X, 0, v.Z).Magnitude - 2) / 20, 0, 1) or 0
	hold.Amt += (goal - hold.Amt) * math.clamp((air and 14 or 8) * dt, 0, 1)
	hold.Phase = (hold.Phase + dt * Bb.Rate) % (2 * math.pi)
	local a = hold.Amt
	holdDelta.X = hold.SwayX + Bb.X * math.sin(hold.Phase) * a
	holdDelta.Y = hold.SwayY - (Bb.Y * (0.5 - 0.5 * math.cos(2 * hold.Phase)) + Bb.Drop) * a
	return holdDelta
end

--- The local Radiant body in first person: the hold on while the right arm is free (no clip, no other shot on it), off
--- for a two-arm clip (Light Lance, Halo, Benediction), another shot (Position Trade's tap), the third-person view, a
--- rebuilt rig or another Element. Called from the step (after the Viewmodel's Update); it acts from the next frame.
local function fpHoldStep(S)
	local VM = need("Viewmodel")
	if not (VM and VM.PlayShot and VM.StopShot and VM.ShotPlaying and VM.ShotPending and VM.ArmClips
		and VM.SetArmOffset and VM.IsPlaying and VM.GetFistCFrame) then return end
	local cam = workspace.CurrentCamera
	local rig = cam and cam:FindFirstChild("SpellshotViewmodel")
	if rig ~= hold.Rig then                               -- a rebuilt rig (a respawn): its shots and offsets are gone
		hold.Rig, hold.On, hold.Offset = rig, false, false
	end
	local want = Config.FPHold and S ~= nil and S.Radiant and rig ~= nil and VM.GetFistCFrame("R") ~= nil
	local mine = hold.On and VM.ShotPlaying("R", Config.HoldShot)
	if not want then
		if mine then VM.StopShot("R", Config.HoldShot) end
		if hold.Offset then
			VM.SetArmOffset("R", nil)
			hold.Offset = false
		end
		hold.On = false
		return
	end
	if hold.On and not mine then hold.On = false end       -- a shot or a clip took the arm
	if VM.IsPlaying() or (not mine and (VM.ShotPending("R") or otherShotOnR(VM))) then
		if mine then VM.StopShot("R", Config.HoldShot) end
		hold.On = false
		return
	end
	if not hold.On and register() and VM.ArmClips[Config.HoldShot] then
		VM.PlayShot("R", Config.HoldShot)                  -- eases in from wherever the arm is
		hold.On = true
	end
	if not hold.Offset then
		VM.SetArmOffset("R", holdOffset)
		hold.Offset = true
	end
end

local function step()
	local now = os.clock()
	local any = false
	for c, S in pairs(chars) do
		if not (c.Parent and S.Humanoid and S.Humanoid.Parent and S.Root and S.Root.Parent) then
			cleanup(c)
		else
			any = true
			-- the carry base: re-asserted now and then (CastPose may drop a body's state and make it again), but never
			-- over another kit's: Cinder Shield (a Technique any Element may slot) rests the body on its hold while the
			-- server's CinderShield attribute is up, and a non-Radiant clip keeps the base it found (review fix 2026-09-29)
			if S.Radiant and now - S.BaseAt >= Config.BaseEvery and not c:GetAttribute("CinderShield")
				and not foreignClip(c) and register() then
				local CP = need("CastPose")
				if CP and CP.Clips and CP.Clips.RadiantCarry then
					pcall(CP.SetBase, c, "RadiantCarry")
					S.BaseSet = true
				end
				S.BaseAt = now
			end
			spinStep(S)
			if S.Radiant then airStep(S, now) end

			local level = glowLevel(S, now)
			S.Level = level
			local st = S.Staff
			local own = (c == player.Character)
			if own then fpHoldStep(S) end
			if st then
				local a, b, u = holdNow(S)
				local world = WORLD[a] or (b ~= nil and WORLD[b])
				local basis = bodyBasis(S)
				local fpShown = false
				if own and fp then
					local fa = fpFrame(a)
					if fa then
						local f = b and lerpFrame(fa, fpFrame(b), u) or fa
						fp.Staff:Place(f)
						fp.Staff:Glow(level)
						fpShown = not hiddenByCaller(S)
					end
				end
				if fp and own then fp.Staff:Show(fpShown) end
				local fa = bodyFrame(S, a, basis)
				local f = b and lerpFrame(fa, bodyFrame(S, b, basis), u) or fa
				if f then
					st:Place(f)
					st:Glow(level)
					-- in first person this player sees the first-person staff (planted too): the world one only without it
					local vis = handVisible(S) or (own and world and not fpShown)
					st:Show(vis and not hiddenByCaller(S))
				else
					st:Show(false)
				end
			end
		end
	end
	if not any and stepBound then
		RunService:UnbindFromRenderStep(Config.StepName)
		stepBound = false
	end
end

ensureBound = function()
	if stepBound then return end
	stepBound = true
	RunService:BindToRenderStep(Config.StepName, Config.StepPriority, step)
end

----------------------------------------------------------------------------------------------------
-- the broadcasts
----------------------------------------------------------------------------------------------------
local function ownRecent(id, within)
	return ownCast[id] ~= nil and os.clock() - ownCast[id] < (within or 0.6)
end

local H = {}

H.RadiantLanceOn = function(d)
	local c = d.Character
	if not isModel(c) or (c == player.Character and lanceHooked) then return end
	lanceBegin(c, d.Id)
end

H.RadiantLance = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local S = chars[c]
	if not (S and S.Lance and not S.Lance.ReleasedAt) then
		if c == player.Character and lanceHooked then return end
		lanceBegin(c, d.Id)
		S = chars[c]
	end
	if S and S.Lance and type(d.Ramp) == "number" then S.Lance.Ramp = d.Ramp end
end

H.RadiantLanceOff = function(d)
	local c = d.Character
	if not isModel(c) or (c == player.Character and lanceHooked) then return end
	lanceEnd(c)
end

H.RadiantBlessing = function(d)
	local c = d.Character
	if not isModel(c) then return end
	if c == player.Character and ownRecent("Blessing") then return end
	local S = stateOf(c)
	local P = table_()
	if not (S and P) then return end
	bodyPlay(c, "RadiantBlessing")
	if c == player.Character then vmShot("L", "RadiantBlessPalm") end
	glowOn(S, "blessing", envGlow(os.clock(), P.Timing.Blessing.Glow))
end

H.RadiantOverflow = function(d)
	local caster = type(d.Caster) == "number" and Players:GetPlayerByUserId(d.Caster) or nil
	local c = caster and caster.Character
	local S = c and stateOf(c)
	local P = table_()
	if not (S and P) then return end
	glowOn(S, "overflow", envGlow(os.clock(), P.Timing.Overflow.Glow))
end

H.RadiantHaloCharge = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local Tn = need("RadiantTuning")
	local windup = type(d.Windup) == "number" and d.Windup
		or ((Tn and Tn.Halo and Tn.Halo.Windup or 0.9) / timeScale())
	haloBegin(c, windup, true)
	if c == player.Character and not ownRecent("Halo", 1.5) then
		local S = chars[c]
		if S and S.Halo then vmPlay("RadiantHaloWindup", S.Halo.Clock) end
	end
end

H.RadiantHaloCancel = function(d)
	if isModel(d.Character) then haloEnd(d.Character, true) end
end

H.RadiantHaloStart = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local S = stateOf(c)
	if S and not (S.Halo and not S.Halo.EndedAt) then haloBegin(c, 0, false) end
end

H.RadiantHaloEnd = function(d)
	if isModel(d.Character) then haloEnd(d.Character, false) end
end

H.RadiantTradeOut = function(d)
	local c = d.Character
	if not isModel(c) then return end
	if c == player.Character and ownRecent("PositionTrade") then return end
	local S = stateOf(c)
	local P = table_()
	if not (S and P) then return end
	local TT = P.Timing.Trade
	-- the broadcast is the dissolve: this clip's 0.12 (the press is already down)
	local clock = clockFrom(os.clock(), TT.Lead)
	bodyPlay(c, "RadiantTrade", clock)
	if S.Radiant then setTrack(S, "RadiantTrade", clock, false) end
	glowOn(S, "trade", function()
		local e = clock()
		if e >= TT.Hidden[2] + TT.BackFade then return nil end
		if e < TT.Hidden[1] then return ramp(e, TT.Rise[1], TT.Rise[2]) end
		if e < TT.Hidden[2] then return 0 end
		return TT.Back * (1 - ramp(e, TT.Hidden[2], TT.BackFade))
	end)
end

H.RadiantBenedictionStart = function(d)
	if isModel(d.Character) then benBegin(d.Character, d) end
end

H.RadiantBenedictionEnd = function(d)
	if isModel(d.Character) then benEnd(d.Character) end
end

-- a pulse refreshes the missed-End timeout (the channel is held: its length is unknown until the End). A pulse after
-- that timeout let go (a stall past Every + Timeout, 2026-09-30 review) means the server is still channelling: the
-- kneel starts again on the same Start, once per let-go (the body clip, the arms and the glow may be over by now)
H.RadiantBenedictionPulse = function(d)
	local c = isModel(d.Character) and d.Character
	local S = c and chars[c]
	if not S then return end
	local B = S.Ben
	if B and not B.EndAt then
		B.LastPulse = serverNow()
		return
	end
	local L = S.BenLast
	if L and L.TimedOut and not L.Resumed and L.Start then
		L.Resumed = true
		benBegin(c, L.Start, serverNow())
	end
end

----------------------------------------------------------------------------------------------------
-- the keypress (this client's own casts): the arms now, the body where the cast is instant
----------------------------------------------------------------------------------------------------
--- arms played on a keypress that the server never confirms (refused: mid-air, a busy slot) let go
local function confirmOrStop(vmClip, confirmed)
	task.delay(Config.ConfirmWait + 2 * ping(), function()
		if not confirmed() then vmStopIf(vmClip) end
	end)
end

RadiantAnim.LocalCast.Blessing = function(character)
	ownCast.Blessing = os.clock()
	vmShot("L", "RadiantBlessPalm")
	local S = stateOf(character)
	local P = table_()
	if not (S and P) then return end
	bodyPlay(character, "RadiantBlessing")
	glowOn(S, "blessing", envGlow(os.clock(), P.Timing.Blessing.Glow))
end

RadiantAnim.LocalCast.PositionTrade = function(character)
	ownCast.PositionTrade = os.clock()
	vmShot("R", "RadiantTradePress")
	local S = stateOf(character)
	local P = table_()
	if not (S and P) then return end
	local TT = P.Timing.Trade
	local clock = clockFrom(os.clock())
	bodyPlay(character, "RadiantTrade", clock)
	if S.Radiant then setTrack(S, "RadiantTrade", clock, false) end
	glowOn(S, "trade", function()
		local e = clock()
		if e >= TT.Hidden[2] + TT.BackFade then return nil end
		if e < TT.Hidden[1] then return ramp(e, TT.Rise[1], TT.Rise[2]) end
		if e < TT.Hidden[2] then return 0 end
		return TT.Back * (1 - ramp(e, TT.Hidden[2], TT.BackFade))
	end)
end

RadiantAnim.LocalCast.Halo = function(character)
	ownCast.Halo = os.clock()
	local Tn = need("RadiantTuning")
	local windup = (Tn and Tn.Halo and Tn.Halo.Windup or 0.9) / timeScale()
	local start = os.clock()
	vmPlay("RadiantHaloWindup", haloClock(start, windup))
	confirmOrStop("RadiantHaloWindup", function()
		local S = chars[character]
		return S ~= nil and S.Halo ~= nil and S.Halo.Start >= start - 0.05
	end)
end

RadiantAnim.LocalCast.Benediction = function(character)
	ownCast.Benediction = os.clock()
	-- The arms from the keypress; once this body's Start arrives, on ITS clock (the server's: the plant lands with the
	-- impact), never stepping back; after its End (or a refused press) the rise. The channel is KEPT here (mine.Ben): the
	-- old clock re-read S.Ben, which the glow clears 0.5 s after the End, and snapped back to the kneel for good -- the
	-- arms stuck in the Benediction pose and the clip never ended (fixed 2026-09-30).
	local mine = { EndAt = nil, Ben = nil, Last = 0 }
	local P = table_()
	local holdT = P and P.Timing.Benediction.Hold or 2.52
	local start = os.clock()
	local function ours()
		local S = chars[character]
		local sb = S and S.Ben
		return (sb and sb.StartedAt and sb.StartedAt >= start - 0.05) and sb or nil
	end
	local clock = function()
		if not mine.Ben then mine.Ben = ours() end
		local sb = mine.Ben
		local c
		if sb then
			c = sb.Clock()
		elseif mine.EndAt then
			c = holdT + (os.clock() - mine.EndAt) * timeScale()
		else
			c = math.min((os.clock() - start) * timeScale(), holdT)
		end
		c = math.max(c, mine.Last)
		mine.Last = c
		return c
	end
	vmPlay("RadiantBenediction", clock)
	confirmOrStop("RadiantBenediction", function()
		if mine.Ben or ours() then return true end
		mine.EndAt = os.clock()                      -- refused: the arms rise out of it
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- the VFX's reads
----------------------------------------------------------------------------------------------------
local function shownStaff(character)
	local S = chars[character]
	if not S then return nil end
	if character == player.Character and fp and fp.Staff.Shown then return fp.Staff end
	return S.Staff
end

function RadiantAnim.StaffPoint(character, name)
	local st = shownStaff(character)
	return st and st:Point(name) or nil
end

function RadiantAnim.StaffCFrame(character)
	local st = shownStaff(character)
	return st and st.Frame or nil
end

function RadiantAnim.StaffLevel(character)
	local S = chars[character]
	return S and S.Level or 0
end

function RadiantAnim.PlantPoint(character)
	local S = chars[character]
	local st = S and S.Staff
	if not (S and S.Plant and st and S.Track and S.Track.Name == "RadiantBenediction") then return nil end
	return st:Point("butt")
end

function RadiantAnim.SetStaffHidden(character, hidden, who)
	local S = stateOf(character)
	if not S then return end
	S.HiddenBy[who or "default"] = hidden and true or nil
end

----------------------------------------------------------------------------------------------------
-- start
----------------------------------------------------------------------------------------------------
local started = false

function RadiantAnim.Start()
	if started then return end
	started = true
	register()
	local function hook(plr)
		plr:GetAttributeChangedSignal("Element"):Connect(function() refresh(plr) end)
		plr.CharacterAdded:Connect(function(c)
			-- the body's joints and hands arrive a beat after the model (ApplyDescription): wait for them
			task.spawn(function()
				local t0 = os.clock()
				while c.Parent == nil or not (c:FindFirstChildOfClass("Humanoid") and c:FindFirstChild("HumanoidRootPart")) do
					if os.clock() - t0 > 10 then return end
					task.wait()
				end
				refresh(plr)
				task.delay(0.5, function()
					local S = chars[c]
					if S then refreshParts(S) end
				end)
			end)
		end)
		plr.CharacterRemoving:Connect(function(c) cleanup(c) end)
		if plr.Character then task.spawn(refresh, plr) end
	end
	for _, plr in ipairs(Players:GetPlayers()) do hook(plr) end
	Players.PlayerAdded:Connect(hook)
	task.spawn(function()
		local remote = iceFolder:WaitForChild("IceAbilityRemote", 30)
		if not remote then
			warnOnce("remote", "IceAbilityRemote not found: no Radiant body animations will play")
			return
		end
		remote.OnClientEvent:Connect(function(action, kind, data)
			if action ~= "VFX" then return end
			local fn = H[kind]
			if not (fn and type(data) == "table") then return end
			task.spawn(function()
				local ok, err = pcall(fn, data)
				if not ok then warnOnce("h" .. tostring(kind), tostring(kind) .. " failed: " .. tostring(err)) end
			end)
		end)
	end)
end

return RadiantAnim
