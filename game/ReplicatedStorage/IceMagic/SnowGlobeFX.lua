--[[
	SnowGlobeFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/SnowGlobeFX

	Cryo's SNOW GLOBE skin (Epic, 2026-10-15), the piece logic: "shake, swirl, settle". Kept OUT of CryoFX (at Luau's
	limit of 200 top-level locals): CryoFX hands it its helpers once (Init: CryoFX._H) and calls in through the hooks
	Frost Lotus already uses -- FBX.Globe(caster) answers for a Snow Globe caster with this module, which takes the same
	calls as FrostLotusFX. The meshes are SnowGlobeKit's. Deep Freeze is not called here: it stays the Default.
	  HitBloom   M1's hit (pass 3): the globe cracks -- thin inked glass slabs fly out, hard shards, a snow pile settles
	  Print      Cold Momentum (pass 3): the icon's footprint (a sole with a snowflake stamp, a heel), a star pop as it lands
	  Field      Flash Freeze (pass 3, from the F icon): the base rim round the zone edge with big upright flakes and a
	             halftone ground patch -- it rises with a wobble, shards billow up and fall, it cracks at the shatter; the
	             rooted body's flakes are CryoFX's "GlobeFF" (SnowGlobeKit.BodyBlooms)
	  Cage*      Mirror Cage (pass 3, from the R icon): a skeleton globe of thick inked ribs (its outline rib turned to the
	             camera) on a tall windowed hexagonal plinth, big flakes billowing up and settling back into it, a chunky
	             dart at each place leaving as the bolt; the ribs crack into shards at the end
	  Storm*     Blizzard: the rim just outside the Frost Line ring, pines round it (tall / short snow-capped, every one
	             turned and scaled its own way), the wall's flecks pure white; in the last stretch the flurry slows,
	             falls and clears (the expiry tell)
]]
local GFX = {}
local H, SG                                       -- CryoFX's helpers (Init), SnowGlobeKit
local rng = Random.new()

function GFX.Init(helpers, kit)
	H, SG = helpers, kit
	GFX.Kit = { Drop = kit.Put }                  -- what CryoFX drops a finished bolt through (back to the pool)
end

function GFX.On(caster)
	return SG ~= nil and SG.Built == true and SG.On(caster)
end

local function tier(caster)
	local enemy = H.Settings.ThinEnemyVFX and caster ~= nil and caster ~= H.VFXLibrary.LocalCharacter
	return SG.Tier(H.Settings.EffectDensity, enemy)
end

local function NS(a, b) return NumberSequence.new(a, b) end

--- `n` snowflakes thrown up from `pos` that drift down and settle (Cryo's own snow sprite)
local function snowPuff(pos, n, up, spread)
	if n <= 0 then return end
	local h = H.host(CFrame.new(pos))
	h.Size = Vector3.new(0.5, 0.5, 0.5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SG.Look.Snow
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission, e.LightInfluence = 0.3, 0.4
	e.Size = NS(0.2, 0.08)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.9, 1.5)
	e.Speed = NumberRange.new(up * 0.5, up)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -3.5, 0)
	e.Drag = 1.6
	e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-60, 60)
	e.Rate = 0
	if H.VFXLibrary.Wrap then H.VFXLibrary.Wrap.Lit(e) end       -- (a solid Cryo wrap: its snow glows, CryoWrap.Lit)
	e.Parent = h
	e:Emit(n)
	task.delay(2, function() h:Destroy() end)
end
GFX.SnowPuff = snowPuff

local function backOut(u)
	local k = 1.7
	u -= 1
	return 1 + u * u * ((k + 1) * u + k)
end

local function groundBelow(p, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(p + Vector3.new(0, 0.3, 0), Vector3.new(0, -9, 0), params)
	return r and r.Position.Y or nil
end

----------------------------------------------------------------------------------------------------
-- M1's HIT (stage 2, from the M1 icon): the globe cracks -- 2-3 thin inked glass slabs fly out and tumble down (each its
-- glint on top), hard shards burst, and a small snow pile settles on the ground below for a moment. All pooled (three a
-- second); opaque, so they go by shrinking. The angular chip burst is CryoFX's own, on the shooter's hit moment.
----------------------------------------------------------------------------------------------------
function GFX.HitBloom(hit, dir)
	local folder = H.fxFolder()
	local p = hit.Position + hit.Normal * 0.1
	local ignore = { folder }
	local body = hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model")
	if body and body:FindFirstChildOfClass("Humanoid") then ignore[2] = body end
	local gy = groundBelow(p, ignore)
	local out = (hit.Normal * 0.7 - dir * 0.3)
	out = out.Magnitude > 1e-3 and out.Unit or -dir
	local side = out:Cross(Vector3.yAxis)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
	local slabs = {}
	for i = 1, SG.Slabs[SG.Tier(H.Settings.EffectDensity, false)] do
		local o = SG.Get("Slab3", folder)
		if o then
			SG.Fade(o, 0)
			local a = 2 * math.pi * i / 3 + rng:NextNumber(-0.5, 0.5)
			local v = (out + side * math.cos(a) * 0.8 + Vector3.new(0, 0.5 + 0.4 * math.sin(a), 0)).Unit * rng:NextNumber(5, 9)
			slabs[#slabs + 1] = { O = o, P = p, V = v, R = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
				W = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(8, 14),
				S = rng:NextNumber(0.9, 1.25) }
		end
	end
	local pile = gy and SG.Get("Pile3", folder) or nil
	local pileAt = gy and Vector3.new(p.X, gy, p.Z) or nil
	if pile then SG.Fade(pile, 1) end
	shards(p, 4, 6, 70, 0.4)
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local a = now - t0
		local alive = false
		for _, s in ipairs(slabs) do
			if s.O then
				if a >= 0.9 then
					SG.Put(s.O)
					s.O = nil
				else
					alive = true
					s.V += Vector3.new(0, -30 * dt, 0)
					s.P += s.V * dt
					if gy and s.P.Y < gy + 0.05 then
						s.P = Vector3.new(s.P.X, gy + 0.05, s.P.Z)
						s.V *= 0.2
						s.W *= 0.3
					end
					s.R = s.R * CFrame.fromAxisAngle(s.W.Magnitude > 0 and s.W.Unit or Vector3.xAxis, s.W.Magnitude * dt)
					local k = 1 - H.smooth((a - 0.6) / 0.3)          -- shrinking away, not fading
					SG.Place(s.O, CFrame.new(s.P) * s.R, parts, cframes, s.S * math.max(0.02, k))
				end
			end
		end
		if pile then
			if a >= 1.3 then
				SG.Put(pile)
				pile = nil
			else
				alive = true
				-- it settles: drops in and spreads (0.1-0.35 s), holds, sinks into the ground (0.9-1.3 s)
				local u = math.clamp((a - 0.1) / 0.25, 0, 1)
				if u > 0 then
					SG.Fade(pile, 0)
					local e = H.easeOut(u)
					local sink = H.smooth((a - 0.9) / 0.4)
					SG.Place(pile, CFrame.new(pileAt + Vector3.new(0, 0.25 * (1 - e) - 0.3 * sink, 0)), parts, cframes, 0.6 + 0.4 * e,
						math.max(0.05, e * (1 - sink)) / (0.6 + 0.4 * e))
				end
			end
		end
		return alive
	end)
end

----------------------------------------------------------------------------------------------------
-- COLD MOMENTUM (stage 2, from its icon): a footprint -- an oval sole with a blue snowflake stamped in it and a heel --
-- on the Default's print (its frame: +Y the ground's normal, the look the run's), a small star popping as it lands; it
-- shrinks away with the print. Pooled.
----------------------------------------------------------------------------------------------------
local POP = "rbxassetid://93429522929420"            -- VFXLibrary.Config.Textures.ShardBurst: the flat comic frost-burst
function GFX.Print(cf, PR)
	local o = SG.Get("Print3", H.fxFolder())
	if not o then return end
	SG.Fade(o, 0)
	local h = H.host(CFrame.new(cf.Position + cf.UpVector * 0.2))
	h.Size = Vector3.new(0.3, 0.3, 0.3)
	local e = H.VFXLibrary.Emitter(h, {
		Texture = POP, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 0.1, LightInfluence = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.22, 0.22), Speed = NumberRange.new(0, 0), Rotation = NumberRange.new(0, 360), Rate = 0,
	})
	e:Emit(1)
	task.delay(1, function() h:Destroy() end)
	local K0 = cf * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, 0.01, 0)    -- (the print frame's long axis is its X: the toe there)
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local age = now - t0
		if age >= PR.Life then
			SG.Put(o)
			return false
		end
		local k = (age < PR.Pop) and (0.6 + 0.4 * H.easeOut(age / PR.Pop)) or 1
		k *= 1 - H.smooth((age - PR.Hold) / (PR.Life - PR.Hold))
		SG.Place(o, K0, parts, cframes, 0.8 * math.max(0.02, k))
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- PASS 3 (2026-10-15: "build the effects from the HUD icons"): the toon pieces -- opaque, banded, ink-hulled, never faded
-- (a piece goes by sinking or shrinking); hard-edged Shard-sprite particles through VFXLibrary's emitter()
----------------------------------------------------------------------------------------------------
local SHARD = "rbxassetid://98211061341574"         -- VFXLibrary.Config.Textures.Shard: the chunky angular chip, hard alpha
local function shards(pos, n, up, spread, size)
	if n <= 0 then return end
	local h = H.host(CFrame.new(pos))
	h.Size = Vector3.new(0.5, 0.5, 0.5)
	local C = H.VFXLibrary.Config.Colors
	local e = H.VFXLibrary.Emitter(h, {
		Texture = H.VFXLibrary.Wrap and H.VFXLibrary.Wrap.Shard(SHARD) or SHARD, Color = (H.VFXLibrary.Wrap and H.VFXLibrary.Wrap.CS or ColorSequence.new)(C.IceLight, C.IceMid), LightEmission = 0.1, LightInfluence = 0.5,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.6), NumberSequenceKeypoint.new(1, (size or 0.6) * 0.7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.88, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(up * 0.6, up), SpreadAngle = Vector2.new(spread, spread),
		EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-240, 240),
		Drag = 1.2, Acceleration = Vector3.new(0, -22, 0), Rate = 0,
	})
	e:Emit(n)
	task.delay(2, function() h:Destroy() end)
end
GFX.Shards = shards

local function fadeNear(o)
	for _, p in ipairs(o.P) do H.VFXLibrary.RegisterProximityFade(p) end
end

----------------------------------------------------------------------------------------------------
-- FLASH FREEZE (VFXLibrary.CastFlashFreeze -> CryoFX.LotusField): the F icon -- the globe's base rim round the zone edge
-- (12 faces, the three bands, the ink, a halftone patch), big flakes standing up on it, a halftone ground patch inside.
-- SHAKE the rim rises with a wobble as the front reaches it; SWIRL the flakes pop up and shards billow; SETTLE they fall
-- back; at the shatter wave the rim and its flakes crack into shards and sink. The rooted body's flakes ride CryoFX's
-- freeze plumbing ("GlobeFF": SnowGlobeKit.BodyBlooms). Times are seconds after the cast.
----------------------------------------------------------------------------------------------------
function GFX.Field(ground, R, leadIn, expand, breakTime, wave, caster)
	if not SG.Kind("Rim1") then return end
	local ti = tier(caster)
	local folder = Instance.new("Folder")
	folder.Name = "SnowGlobeField"
	folder.Parent = H.fxFolder()
	local c = ground.Position
	local dens = H.density(caster)
	local rr = R + 0.3                                   -- just outside the Default's Frost Line ring (the line IS the edge)
	local s, sy = rr / SG.RefR, SG.RefR / rr
	local rise = leadIn + expand                        -- the front reaches the rim
	local rimBreak = breakTime + wave
	local rim, flakes = {}, {}
	for f = 1, 12 do
		local o = SG.New("Rim" .. f, folder)
		if o then
			SG.Fade(o, 1)
			fadeNear(o)
			rim[#rim + 1] = { O = o, T = rise - 0.12 + 0.02 * f, Ph = rng:NextNumber(0, 6.28) }
		end
	end
	local nf = SG.RimFlakes[ti]
	for k = 0, nf - 1 do
		local o = SG.New("Hero", folder)
		if o then
			SG.Fade(o, 1)
			local a = math.pi / 6 + 2 * math.pi * k / nf
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			flakes[#flakes + 1] = { O = o, Out = out, P = c + out * (rr + 0.75 * s) + Vector3.new(0, SG.RimH + 2.0, 0),
				T = rise + 0.08 + 0.03 * k, Ph = rng:NextNumber(0, 6.28) }
		end
	end
	local dots = SG.New("Dots", folder)
	if dots then SG.Fade(dots, 1) end
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		if not folder.Parent or t > rimBreak + 0.6 then
			folder:Destroy()
			return false
		end
		local bk = t - rimBreak
		-- SHAKE: the rim rises round the edge with an overshoot and a wobble; at the shatter it cracks and sinks
		for _, sec in ipairs(rim) do
			local u = (t - sec.T) / 0.35
			if u > 0 then
				local y
				if bk > 0 then
					y = -(SG.RimH + 0.2) * math.min(bk / 0.4, 1)
				else
					y = -(SG.RimH + 0.2) * (1 - backOut(math.min(u, 1))) + 0.08 * math.sin(t * 20 + sec.Ph) * math.exp(-3 * u)
				end
				SG.Fade(sec.O, 0)
				SG.Place(sec.O, CFrame.new(c + Vector3.new(0, y, 0)), parts, cframes, s, sy)
			end
		end
		-- SWIRL: the flakes pop up on the rim, wobbling; at the shatter each cracks into shards
		for _, fl in ipairs(flakes) do
			local u = (t - fl.T) / 0.3
			if u > 0 and fl.O then
				if bk > 0 then
					if not fl.Cracked then
						fl.Cracked = true
						H.burst(fl.P, fl.Out + Vector3.new(0, 0.5, 0), { Chips = 4, Powder = 1 }, dens, 1)
						shards(fl.P, 5, 9, 70, 0.7)
					end
					local k = 1 - math.min(bk / 0.2, 1)
					if k <= 0 then
						SG.Drop(fl.O)
						fl.O = nil
					else
						SG.Place(fl.O, CFrame.fromMatrix(fl.P, Vector3.new(-fl.Out.Z, 0, fl.Out.X), fl.Out), parts, cframes, 2.0 * k)
					end
				else
					if not fl.Popped then
						fl.Popped = true
						shards(fl.P - Vector3.new(0, 1.5, 0), 4, 11, 35, 0.6)     -- the billow: shards thrown up, falling back
					end
					SG.Fade(fl.O, 0)
					local k = backOut(math.min(u, 1))
					local rot = CFrame.Angles(0, 0, 0.18 * math.sin(t * 9 + fl.Ph) * math.exp(-2.5 * u))
					SG.Place(fl.O, CFrame.fromMatrix(fl.P, Vector3.new(-fl.Out.Z, 0, fl.Out.X), fl.Out) * rot, parts, cframes, 2.0 * math.max(0.03, k))
				end
			end
		end
		-- the halftone ground patch: in with the front, sinking at the end
		if dots then
			local u = (t - (leadIn + expand * 0.4)) / 0.3
			if u > 0 then
				SG.Fade(dots, (bk > 0.25) and 1 or 0)
				SG.Place(dots, CFrame.new(c + Vector3.new(0, 0.02, 0)), parts, cframes, (R / SG.RefR) * (0.85 + 0.15 * math.min(u, 1)), 1)
			end
		end
		if bk > 0 and not folder:GetAttribute("Burst") then
			folder:SetAttribute("Burst", true)
			for k = 0, 11, (ti == 3) and 2 or 1 do
				local a = 2 * math.pi * (k + 0.5) / 12
				local p = c + Vector3.new(math.cos(a) * (rr + 0.8 * s), 0.9, math.sin(a) * (rr + 0.8 * s))
				H.burst(p, Vector3.new(math.cos(a), 0.6, math.sin(a)), { Chips = 3, Powder = 1 }, dens, 0.9)
				shards(p, 2, 8, 60, 0.55)
			end
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- MIRROR CAGE (CryoFX.MirrorCage keeps its layout, timings, fire list and flight; these are the looks): the R icon -- a
-- skeleton globe (six thick inked meridians to a hexagonal hub, two latitude rings, the white one the icon's inner ring;
-- open faces to see and shoot through) whose outline rib always faces the camera, on a tall hexagonal plinth with
-- windows, the white stripe and a halftone patch; big flakes inside; a chunky dart at each place. SHAKE the frame wobbles
-- as it forms; SWIRL the flakes billow up off the plinth; SETTLE over the volley they sink back into it; at the end the
-- ribs crack into shards.
----------------------------------------------------------------------------------------------------
local function layer(name, folder)
	local o = SG.New(name, folder)
	if o then SG.Fade(o, 1) end
	return o
end

local HERO_SPOTS = { { 0.2, 11.0, 7.5 }, { 1.25, 13.5, 6.0 }, { 2.3, 9.5, 9.5 }, { 3.3, 14.5, 4.0 }, { 4.3, 10.5, 8.0 }, { 5.4, 12.5, 5.5 } }

function GFX.CageSetup(cage, aimAt, thin, center, gy)
	local ti = thin and 3 or SG.Tier(H.Settings.EffectDensity, false)
	local folder = cage.Folder
	local G
	if center and gy then
		G = Vector3.new(center.X, gy, center.Z)
	else
		local sum, lo = Vector3.zero, math.huge
		for _, pn in ipairs(cage.Panels) do sum += pn.Pos lo = math.min(lo, pn.Pos.Y) end
		local m = sum / math.max(1, #cage.Panels)
		G = Vector3.new(m.X, gy or (lo - 1), m.Z)
	end
	local DC = G + Vector3.new(0, SG.DomeY, 0)
	local R, nR, fire = 0, 0, 0
	for _, pn in ipairs(cage.Panels) do
		R += (pn.Pos - DC).Magnitude
		nR += 1
		fire = math.max(fire, pn.Form or 0)
	end
	R = nR > 0 and R / nR or SG.RefR
	local g = { G = G, R = R, s = R / SG.RefR, Ribs = layer("Ribs", folder), Outline = layer("Outline", folder), Plinth = {},
		Flakes = {}, Settle = fire + 0.4 }
	for _, o in ipairs({ g.Ribs, g.Outline }) do fadeNear(o) end
	for f = 1, 6 do
		local o = layer("Plinth" .. f, folder)
		if o then
			fadeNear(o)
			g.Plinth[#g.Plinth + 1] = { O = o, T = 0.03 * f, Ph = rng:NextNumber(0, 6.28) }
		end
	end
	for k = 1, SG.HeroFlakes[ti] do
		local sp = HERO_SPOTS[k]
		local o = layer("Hero", folder)
		if o then
			g.Flakes[#g.Flakes + 1] = { O = o, Az = sp[1], Y = sp[2], Rr = sp[3], Spin = rng:NextNumber(0.4, 0.9) * ((k % 2 == 0) and 1 or -1),
				Tilt = rng:NextNumber(-0.5, 0.5), Delay = 0.05 * k }
		end
	end
	-- low snow drifts at the inner edge (knee high at most), building up as the flakes settle
	g.Drifts = {}
	for k = 0, 11 do
		local o = layer("Drift3", folder)
		if o then
			g.Drifts[#g.Drifts + 1] = { O = o, A = 2 * math.pi * (k + 0.5) / 12 + rng:NextNumber(-0.08, 0.08), S = rng:NextNumber(0.8, 1.15),
				Lag = 0.07 * (k % 4) }
		end
	end
	-- chunky hard-edged snow falling inside the globe (the Shard sprite, through emitter())
	local fall = H.host(CFrame.new(G + Vector3.new(0, 14 * g.s, 0)))
	fall.Size = Vector3.new(R * 1.1, 0.2, R * 1.1)
	local CC = H.VFXLibrary.Config.Colors
	g.FallE = H.VFXLibrary.Emitter(fall, {
		Texture = H.VFXLibrary.Wrap and H.VFXLibrary.Wrap.Shard(SHARD) or SHARD, Shape = Enum.ParticleEmitterShape.Box, Color = (H.VFXLibrary.Wrap and H.VFXLibrary.Wrap.CS or ColorSequence.new)(CC.Rim, CC.IceLight), LightEmission = 0.1,
		LightInfluence = 0.5, Size = NumberSequence.new(0.42, 0.34),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.9, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.6, 3.2), Speed = NumberRange.new(1, 2.5), EmissionDirection = Enum.NormalId.Bottom,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), Acceleration = Vector3.new(0, -2.5, 0), Drag = 0.4,
		Rate = thin and 5 or 11,
	})
	g.Fall = fall
	for k = 0, 5 do                                       -- the billow off the plinth
		local a = math.pi / 6 + k * math.pi / 3
		shards(G + Vector3.new(math.cos(a) * (R - 1), 4.4, math.sin(a) * (R - 1)), thin and 2 or 4, 14, 30, 0.7)
	end
	cage.SG = g
	-- a chunky dart at every place, pointing in: it leaves as the bolt and regrows (CryoFX checks Blooms)
	cage.Blooms = {}
	for _, pn in ipairs(cage.Panels) do
		local o = layer("Dart3", folder)
		if o then
			local inn = (aimAt - pn.Pos).Unit
			pn.Bloom = { O = o, K = SG.Frame(pn.Pos - inn * (SG.Dart3L * 0.5), inn, Vector3.yAxis), Form = pn.Form, At = pn.Pos, PeelT = -1 }
			cage.Blooms[#cage.Blooms + 1] = pn.Bloom
		end
	end
end

function GFX.CageStep(cage, age, parts, cframes, condense, impU)
	local g = cage.SG
	if not g then return end
	-- SHAKE: the frame forms in 0.35 s, squashing and stretching and rocking like a shaken globe
	local form = H.easeOut(math.clamp(age / 0.35, 0, 1))
	local damp = math.exp(-3 * age)
	local wob = 0.09 * math.sin(age * 15) * math.exp(-2.5 * age)     -- squash and stretch only: the rings stay level with the base
	local _ = damp
	local s = g.s * math.max(0.02, form)
	local K0 = CFrame.new(g.G)
	if g.Ribs then
		SG.Fade(g.Ribs, 0)
		SG.Place(g.Ribs, K0, parts, cframes, s * (1 - 0.5 * wob), (1 + wob) / (1 - 0.5 * wob))
	end
	local cam = workspace.CurrentCamera
	if g.Outline and cam then
		local cp = cam.CFrame.Position
		local inside = (cp - g.G).Magnitude < g.R
		SG.Fade(g.Outline, inside and 1 or 0)
		if not inside then
			local b = g.G + Vector3.new(0, SG.DomeY * s, 0)
			SG.Place(g.Outline, CFrame.lookAt(b, Vector3.new(cp.X, b.Y, cp.Z)), parts, cframes, s * (1 - 0.5 * wob), (1 + wob) / (1 - 0.5 * wob))
		end
	end
	for _, p in ipairs(g.Plinth) do
		local u = (age - p.T) / 0.35
		if u > 0 then
			SG.Fade(p.O, 0)
			local y = -(SG.PlinthH + 0.3) * (1 - backOut(math.min(u, 1))) + 0.07 * math.sin(age * 18 + p.Ph) * math.exp(-3 * u)
			SG.Place(p.O, CFrame.new(g.G + Vector3.new(0, y, 0)), parts, cframes, g.s, 1 / g.s)
		end
	end
	-- SWIRL: the flakes billow up off the plinth to their places (0-0.9 s), turning; SETTLE: over the volley they drift
	-- out and down and sink back into the plinth, shrinking as they go in -- out by the wall, never over the target's head
	local settle = H.smooth((age - g.Settle) / 1.6)
	for _, f in ipairs(g.Flakes) do
		local up = H.easeOut(math.clamp((age - f.Delay) / 0.9, 0, 1))
		local rr = (g.R - 3) + (f.Rr - (g.R - 3)) * up
		rr += (g.R - 1.0 - rr) * settle
		local y = 4.4 + (f.Y - 4.4) * up
		y += (SG.PlinthH - y) * settle
		local a = f.Az + f.Spin * 0.25 * age
		local p = g.G + Vector3.new(math.cos(a) * rr * g.s, y, math.sin(a) * rr * g.s)
		local k = (up <= 0) and 0 or 3.4 * math.max(0.03, 1 - settle * settle)
		if k <= 0.08 then
			SG.Fade(f.O, 1)
		else
			SG.Fade(f.O, 0)
			local face = Vector3.new(math.cos(a + 2.2), 0.25, math.sin(a + 2.2)).Unit
			SG.Place(f.O, SG.BloomFrame(p, face, f.Spin * age) * CFrame.Angles(f.Tilt, 0, 0), parts, cframes, k)
		end
	end
	-- the drifts build up at the inner edge as the snow settles
	for _, d in ipairs(g.Drifts) do
		local u = H.easeOut(math.clamp((settle - d.Lag) / 0.6, 0, 1))
		if u <= 0 then
			SG.Fade(d.O, 1)
		else
			SG.Fade(d.O, 0)
			local pos = g.G + Vector3.new(math.cos(d.A), 0, math.sin(d.A)) * ((g.R - 1.4) * g.s)
			SG.Place(d.O, CFrame.fromMatrix(pos, Vector3.new(-math.sin(d.A), 0, math.cos(d.A)), Vector3.yAxis), parts, cframes, d.S * math.max(0.03, u))
		end
	end
	if g.FallE then g.FallE.Enabled = (impU or 0) < 0.5 end
	-- the darts: each on its place's beat, regrowing after it leaves
	for _, b in ipairs(cage.Blooms or {}) do
		local cond = H.easeOut((age - b.Form) / condense)
		if age >= b.Form - 0.02 and cond > 0 then
			local re = (b.PeelT >= 0) and math.clamp((os.clock() - b.PeelT - 0.05) / 0.3, 0, 1) or 1
			SG.Fade(b.O, (re <= 0) and 1 or 0)
			SG.Place(b.O, b.K, parts, cframes, math.max(0.02, cond * re))
		end
	end
end

--- where a bolt leaves: the dart at that place (it leaves; it regrows)
function GFX.BoltFrom(pn, aimAt)
	local b = pn.Bloom
	if b then b.PeelT = os.clock() end
	return b and b.At or pn.Pos
end

function GFX.NewBolt(folder)
	local o = SG.Get("Dart3", folder)
	if o then SG.Fade(o, 0) end
	return o
end

function GFX.Peel(pos) shards(pos, 2, 3, 60, 0.45) end
function GFX.Strike(pos) shards(pos, 4, 7, 80, 0.5) end

--- the bolt at flight fraction u: straight, point first, turning round its line
function GFX.PlaceBolt(fly, u, parts, cframes)
	local d = fly.To - fly.From
	local dir = d.Unit
	local e1 = dir:Cross(Vector3.yAxis)
	if e1.Magnitude < 1e-3 then e1 = dir:Cross(Vector3.xAxis) end
	e1 = e1.Unit
	local e2 = dir:Cross(e1)
	local roll = u * 4 * math.pi
	local p = fly.From + d * u
	SG.Place(fly.O, SG.Frame(p - dir * SG.Dart3L, dir, e1 * math.cos(roll) + e2 * math.sin(roll)), parts, cframes)
end

local function dropCage(g)
	for _, o in ipairs({ g.Ribs, g.Outline }) do SG.Drop(o) end
	for _, list in ipairs({ g.Plinth, g.Flakes, g.Drifts or {} }) do
		for _, x in ipairs(list) do SG.Drop(x.O) end
	end
	if g.Fall then g.Fall:Destroy() g.Fall = nil end
end

--- the end: the ribs crack into hard-edged shards (the frame snaps away), the flakes burst, the plinth sinks
function GFX.CageBurst(cage, aimAt, gy, thin)
	local g = cage.SG
	for _, b in ipairs(cage.Blooms or {}) do SG.Drop(b.O) end
	cage.Blooms, cage.SG = nil, nil
	if not g then return end
	local dens = H.density(nil)
	local DC = g.G + Vector3.new(0, SG.DomeY * g.s, 0)
	for k = 0, (thin and 5 or 11) do                    -- along the meridians and round the rings
		local az = math.pi / 6 + (k % 6) * math.pi / 3
		local e = math.rad((k < 6) and 35 or 62)
		local p = DC + Vector3.new(math.cos(e) * math.cos(az), math.sin(e), math.cos(e) * math.sin(az)) * g.R
		H.burst(p, (p - DC).Unit, { Chips = 5, Powder = 1 }, dens, 1.1)
		shards(p, 4, 10, 80, 0.8)
	end
	for _, list in ipairs({ g.Flakes, g.Drifts or {} }) do
		for _, f in ipairs(list) do
			if f.O and f.O.P[1] and f.O.P[1].Transparency < 1 then shards(f.O.P[1].Position, 3, 8, 90, 0.6) end
		end
	end
	if g.FallE then g.FallE.Enabled = false end
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local a = now - t0
		if a >= 0.45 then
			dropCage(g)
			return false
		end
		local k = 1 - math.min(a / 0.18, 1)                 -- the frame snaps away fast
		for _, o in ipairs({ g.Ribs, g.Outline }) do if o then SG.Fade(o, (k <= 0) and 1 or 0) end end
		if g.Ribs and k > 0 then SG.Place(g.Ribs, CFrame.new(g.G), parts, cframes, g.s * (1 + 0.04 * (1 - k)) * math.max(0.05, k)) end
		if g.Outline then SG.Fade(g.Outline, 1) end
		for _, f in ipairs(g.Flakes) do if f.O then SG.Fade(f.O, 1) end end
		for _, p in ipairs(g.Plinth) do
			if p.O then
				SG.Place(p.O, CFrame.new(g.G - Vector3.new(0, (SG.PlinthH + 0.3) * math.min(a / 0.4, 1), 0)), parts, cframes, g.s, 1 / g.s)
			end
		end
		return true
	end)
end

function GFX.CageDrop(cage)
	for _, b in ipairs(cage.Blooms or {}) do SG.Drop(b.O) end
	if cage.SG then dropCage(cage.SG) end
	cage.Blooms, cage.SG = nil, nil
end

----------------------------------------------------------------------------------------------------
-- BLIZZARD: the wall's flecks pure white (the same emitters, rates and count: the obstruction is the Default's); the rim
-- just outside the Frost Line ring, the pines round it; the expiry tell: from the Default's own thinning on, the flurry
-- slows, falls and clears
----------------------------------------------------------------------------------------------------
function GFX.StormFleck(props)
	props.Name = "SnowGlobeFleck"
	props.Color = ColorSequence.new(Color3.new(1, 1, 1))
	props.LightEmission = 0.25
end

function GFX.Storm(s, c, R, form, caster)
	-- stage 3 (pass 3, from the Q icon): the curb rim just outside the Frost Line ring, big inked pines round it (tall and
	-- short, every one turned and scaled its own way), the flurry -- wide white crescent tiers turning with the wall. The
	-- wall's flecks run at 70% to offset the crescents (the obstruction stays at or under the Default's). The expiry tell:
	-- from the Default's own thinning on, flecks and flurry slow, fall and clear; rim and pines sink.
	local ti = tier(caster)
	local folder = s.Folder
	local sc = (R + 0.25) / SG.RefR
	local rim, pines = {}, {}
	for f = 1, 12 do
		local o = layer("BzRim" .. f, folder)
		if o then
			fadeNear(o)
			rim[#rim + 1] = { O = o, T = 0.2 + 0.03 * f, Ph = rng:NextNumber(0, 6.28) }
		end
	end
	local n = SG.Pines[ti]
	for i = 1, n do
		local o = layer((i % 2 == 1) and "PineT" or "PineS", folder)
		if o then
			local a = 2 * math.pi * (i - 0.5) / n + rng:NextNumber(-0.15, 0.15)
			local r = R * rng:NextNumber(0.55, 0.82)              -- inside the storm, big (the developer's call, 2026-10-15)
			pines[#pines + 1] = { O = o, P = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), Yaw = rng:NextNumber(0, 6.28),
				S = rng:NextNumber(1.5, 1.9), T = form * 0.5 + 0.06 * i }
		end
	end
	local fl = layer("Flurry", folder)
	local fs = R / SG.BzR
	local flecks = {}
	for _, em in ipairs(s.Emitters or {}) do
		if em.E and em.E.Name == "SnowGlobeFleck" then
			em.Rate *= 0.7
			flecks[#flecks + 1] = { E = em.E, Acc = em.E.Acceleration, Sp = em.E.Speed, Rs = em.E.RotSpeed }
		end
	end
	local th, last = 0, nil
	H.run(function(now, dt, parts, cframes)
		if not folder.Parent then
			for _, x in ipairs(rim) do SG.Drop(x.O) end
			for _, x in ipairs(pines) do SG.Drop(x.O) end
			SG.Drop(fl)
			return false
		end
		local age = H.serverNow() - s.T0
		local thinAt = s.Ended and s.EndAge or (s.Duration - 1.8)
		local endAt = s.Ended and s.EndAge or s.Duration
		local q = H.smooth((age - thinAt) / 1.4)
		for _, f in ipairs(flecks) do
			if f.Q ~= q then
				f.Q = q
				f.E.Acceleration = f.Acc:Lerp(Vector3.new(0, -9, 0), q)
				f.E.Speed = NumberRange.new(f.Sp.Min * (1 - 0.7 * q), f.Sp.Max * (1 - 0.7 * q))
				f.E.RotSpeed = NumberRange.new(f.Rs.Min * (1 - 0.8 * q), f.Rs.Max * (1 - 0.8 * q))
			end
		end
		local gone = H.smooth((age - endAt) / 0.8)
		for _, x in ipairs(rim) do
			local u = (age - x.T) / 0.35
			if u > 0 then
				SG.Fade(x.O, (gone >= 1) and 1 or 0)
				local y = -(SG.RimH + 0.2) * (1 - backOut(math.min(u, 1))) + 0.06 * math.sin(age * 20 + x.Ph) * math.exp(-3 * u)
					- (SG.RimH + 0.2) * gone
				SG.Place(x.O, CFrame.new(c + Vector3.new(0, y, 0)), parts, cframes, sc, 1 / sc)
			end
		end
		for _, p in ipairs(pines) do
			local u = (age - p.T) / 0.45
			if u > 0 then
				local k = backOut(math.min(u, 1)) * (1 - gone)
				SG.Fade(p.O, (k <= 0.02) and 1 or 0)
				SG.Place(p.O, CFrame.new(p.P - Vector3.new(0, 1.2 * gone, 0)) * CFrame.Angles(0, p.Yaw, 0), parts, cframes, p.S * math.max(0.02, k))
			end
		end
		if fl then
			local dt2 = last and math.clamp(age - last, 0, 0.1) or 0
			last = age
			th -= 0.6 * (1 - 0.85 * q) * dt2                       -- turning with the wall, slowing at the end
			local grow = H.easeOut(math.clamp((age - form * 0.6) / 0.8, 0, 1)) * (1 - q)
			SG.Fade(fl, (grow <= 0.02) and 1 or 0)
			SG.Place(fl, CFrame.new(c - Vector3.new(0, 6 * q, 0)) * CFrame.Angles(0, th, 0), parts, cframes, fs * math.max(0.02, grow))
		end
		return true
	end)
end

return GFX
