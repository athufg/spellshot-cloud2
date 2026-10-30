--[[
	HydraKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/HydraKit

	Toxin's HYDRA (2026-10-21; the MYTHIC Element skin, Toxin's top tier): one venomous many-headed serpent drawn across
	the whole kit. This module holds its forms; HydraFX performs them on the Default's beats through ToxinFX's skin hooks,
	gated on On(). Built procedurally in Studio (no Blender export), from closed EditableMesh grids, per client, lazily.
	THE CREATURE'S PART CLASSES -- every head, neck and the helm, in every ability, are made of these, nothing else.
	Modelled hard-surface in Blender (vfx_blocking/toxin/hydra_2026_10_21/helm: hydra_creature.py, hydra_helm.py), exported
	by hydra_export.py into HydraData (one mesh per class per asset) and built here per client, one mesh a frame:
	  Scale   the dark jade body (skull, jaw, neck segments, the helm's shell)
	  Plate   the light jade armour plates (dorsal scutes, brow plates, cheek scales, the neck's plate and keel, faceplate)
	  Tile    the helm's scale plates          Belly  the pale ventral scutes          Inner  the helm's inside and seams
	  Fang    ivory: fangs, horns, crest spines, the neck spikes, the helm's fang brow and crest, Acid Rain's spines
	  Frill   the membrane between the crest spines (translucent)
	  Glow    Neon edge ribbons on the hard edges: eye-slits, ribbons, lip lines, the neck's seam and throat vein, the
	          helm's eye-slits and serpent engravings
	  Core    Neon, the self-lit core: the venom gem in each skull and the throat crystal (HydraFX lights it)
	ONE head and ONE neck segment serve every ability, at sizes and counts; the helm is the one separate asset.
	  Head(scale)         a serpent head: HeadSkull + HeadJaw (hinged); PlaceHead(h, cf, jaw) poses it (cf: the hinge, -Z
	                      forward)
	  Neck(scale, n)      n armoured NeckSeg segments, tapering; PlaceNeck(neck, curve, side) lays it along a curve and
	                      returns the end frame (a head sits there)
	  Helm(scale)         the Vent's helm: HelmBack (worn always) + HelmFace, ONE rigid faceplate on ONE hinge at the top
	                      front of the head; PlaceHelm(h, headCF, hs, open) swings it
	  Glob()              the M1 venom glob: venom glass round a Core, a Glow seam
	  Barb(...)           a lone Fang (Acid Rain's spines)
	  On(character)       its player is Toxin and SkinCatalog's ElementSkin_Toxin is "Hydra"; Studio only: a body with
	                      StudioSkin = "Hydra" stands in (never live). A true answer starts the build (Prepare).
	  FlecksOn()/GlintsOn()  the particle layers' own switches: ReplicatedStorage.IceMagic attributes HydraFlecks and
	                      HydraGlints (absent or true: on)
	  Tex()               painted images: Sigil (the Ultimate's ring), Etch, Crack (the Corroded scales), Flake, Dot,
	                      Glint (a four-point star: the Epic layer)
	  OnRelease(fn) / ReleaseNow()   (2026-10-26) the give-back: worn by nobody here and idle 10 s, it lets go of its meshes
	                      (MeshBudget's Optional; ReleaseNow skips the idle wait); OnRelease's fns empty the pools elsewhere
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local HK = {}
HK.Id = "Hydra"
HK.Built = false
HK.Failed = false
HK.Tris = 0

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- the colours: Toxin's own venom green as the creature's light, round a darker, richer scale than any lower tier
HK.Look = {
	Scale = rgb(46, 88, 54),         -- (jade scale: (36,64,40) rendered black under the grade)
	ScaleEdge = rgb(78, 120, 64),    -- (the lighter plates: alternating down the necks)
	Belly = rgb(136, 148, 96),       -- (the pale jaw and throat plates)
	Fang = rgb(226, 218, 186),       -- (ivory)
	Frill = rgb(112, 146, 52),       -- (the membranes: translucent amber-green)
	Glass = rgb(172, 198, 58),       -- (venom glass: the throats, the glob)
	VenomGlass = rgb(64, 146, 46),   -- (the helm's visor: tinted, see-through glass over its lit venom core)
	Glow = rgb(140, 175, 80),        -- (Neon edge ribbons and seams: Toxin's shipped ToxinTuning Neon.Virulence)
	Seam = rgb(140, 175, 80),
	Core = rgb(160, 200, 78),        -- (Neon: the venom hearts, a little hotter than the edges)
	Eye = rgb(186, 214, 92),
	Vein = rgb(122, 160, 62),        -- (Neon: the throat vein at rest; it flares toward Core as the creature feeds)
	Venom = rgb(172, 198, 58),
	VenomDeep = rgb(96, 116, 26),
	Dust = rgb(96, 112, 62),
	Etch = rgb(40, 42, 18),
	Tile = rgb(58, 106, 62),         -- (the helm's scale plates)
	Inner = rgb(62, 86, 58),         -- (the helm's inside and its seams: lit enough to read when the faceplate is up)
}

function HK.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

local function folderAttr(name)
	local f = ReplicatedStorage:FindFirstChild("IceMagic")
	return f and f:GetAttribute(name)
end
function HK.FlecksOn() return folderAttr("HydraFlecks") ~= false end
function HK.GlintsOn() return folderAttr("HydraGlints") ~= false end

----------------------------------------------------------------------------------------------------
-- MESHES: closed grid surfaces built once per client through MeshBudget (Essential, with retry), copied fixed-size.
----------------------------------------------------------------------------------------------------
local MeshBudget = nil
local function budget()
	if MeshBudget == nil then
		local m = script.Parent:FindFirstChild("MeshBudget")
		local ok, b = pcall(function() return m and require(m) end)
		MeshBudget = (ok and type(b) == "table") and b or false
	end
	return MeshBudget or nil
end
local function retry(make)
	for i = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		local b = budget()
		if b and i % 8 == 1 then b.MakeRoom() end
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}                                                   -- (the built set's fixed meshes; swapped on a quality change)
local function sp(t, e) return (t < 0 and -1 or 1) * math.abs(t) ^ e end
-- a closed mesh from a surface P(u, v) (u: 0..1 end to end, v: 0..1 round; shared vertices, smooth normals from the
-- grid's own tangents, turned outward by a majority vote against the shape's centroid -- right for curled tubes too);
-- its points are centred on their bounds (a MeshPart centres its mesh). Returns { Part, Off (the bounds' centre, design
-- units), Size }
local function gridMesh(P, nu, nv)
	local pts = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local sum, count = Vector3.zero, 0
	for i = 0, nu do
		pts[i] = {}
		for j = 0, nv - 1 do
			local p = P(i / nu, j / nv)
			pts[i][j] = p
			lo, hi = lo:Min(p), hi:Max(p)
			sum += p
			count += 1
		end
	end
	local centroid = sum / count
	local off = (lo + hi) / 2
	local nrm = {}
	local vote = 0
	for i = 0, nu do
		nrm[i] = {}
		for j = 0, nv - 1 do
			local du = pts[math.min(nu, i + 1)][j] - pts[math.max(0, i - 1)][j]
			local dv = pts[i][(j + 1) % nv] - pts[i][(j - 1) % nv]
			local n = du:Cross(dv)
			nrm[i][j] = n
			if n.Magnitude > 1e-7 then vote += (n:Dot(pts[i][j] - centroid) >= 0) and 1 or -1 end
		end
	end
	local flip = (vote < 0) and -1 or 1
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		local vid, nid, unit = {}, {}, {}
		for i = 0, nu do
			vid[i], nid[i], unit[i] = {}, {}, {}
			for j = 0, nv - 1 do
				vid[i][j] = em:AddVertex(pts[i][j] - off)
				local n = nrm[i][j] * flip
				if n.Magnitude < 1e-7 then                            -- (a pole: straight out from the centroid)
					n = pts[i][j] - centroid
					if n.Magnitude < 1e-7 then n = Vector3.yAxis end
				end
				unit[i][j] = n.Unit
				nid[i][j] = em:AddNormal(n.Unit)
			end
		end
		for i = 0, nu - 1 do
			for j = 0, nv - 1 do
				local j2 = (j + 1) % nv
				local quad = { { i, j }, { i, j2 }, { i + 1, j2 }, { i + 1, j } }
				for _, t in ipairs({ { 1, 2, 3 }, { 1, 3, 4 } }) do
					local a, b, c = quad[t[1]], quad[t[2]], quad[t[3]]
					local A, B, C = pts[a[1]][a[2]], pts[b[1]][b[2]], pts[c[1]][c[2]]
					local fn = (B - A):Cross(C - A)
					if fn.Magnitude > 1e-9 then
						local want = unit[a[1]][a[2]] + unit[b[1]][b[2]] + unit[c[1]][c[2]]
						if fn:Dot(want) < 0 then b, c = c, b end
						local f = em:AddTriangle(vid[a[1]][a[2]], vid[b[1]][b[2]], vid[c[1]][c[2]])
						em:SetFaceNormals(f, { nid[a[1]][a[2]], nid[b[1]][b[2]], nid[c[1]][c[2]] })
						if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
						HK.Tris += 1
					end
				end
			end
		end
	end)
	if not okB then
		em:Destroy()
		error(errB, 0)
	end
	local okF, fixed = pcall(retry, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	em:Destroy()
	if not okF then error(fixed, 0) end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise })
	end)
	if not ok then
		local ok2, mp2 = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
		if not ok2 then
			fixed:Destroy()
			error(mp2, 0)
		end
		mp = mp2
	end
	keep[#keep + 1] = fixed
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Material, mp.Reflectance = Enum.Material.SmoothPlastic, 0
	return { Part = mp, Off = off, Size = hi - lo }
end

-- THE BARB (design units; its base disc at the origin, straight along +Z, then hooking round toward -Y): a swept tube
-- tapering to a point. Length ~0.9, base radius 0.16
local function barbCentre(s)
	if s <= 0.5 then return Vector3.new(0, 0, s / 0.5 * 0.45), Vector3.new(0, 0, 1) end
	local a = (s - 0.5) / 0.5 * math.rad(115)
	local R = 0.3
	return Vector3.new(0, -R * (1 - math.cos(a)), 0.45 + R * math.sin(a)), Vector3.new(0, -math.sin(a), math.cos(a))
end
local function barbAt(u, v)
	local ph = v * 2 * math.pi
	if u < 0.08 then                                              -- (the closed base)
		local r = 0.16 * (u / 0.08)
		return Vector3.new(r * math.cos(ph), r * math.sin(ph), 0)
	end
	local s = (u - 0.08) / 0.92
	local c, t = barbCentre(s)
	local r = 0.16 * (1 - s) ^ 0.85 + 0.002
	local n = Vector3.new(0, t.Z, -t.Y)                           -- (in the curl's plane, square to it)
	return c + (Vector3.xAxis * math.cos(ph) + n * math.sin(ph)) * r
end
-- a mesh from HydraData (Blender-modelled, one part class): unique vertices (thousandths of a stud, Roblox axes) and
-- triangles (0-based), flat-shaded (a normal per face); its points centred on their bounds. { Part, Off, Size }
local function dataMesh(V, T)
	local vs, ts = string.split(V, ","), string.split(T, ",")
	local pts = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 1, #vs, 3 do
		local p = Vector3.new(tonumber(vs[i]), tonumber(vs[i + 1]), tonumber(vs[i + 2])) / 1000
		pts[#pts + 1] = p
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local off = (lo + hi) / 2
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		local vid = {}
		for i, p in ipairs(pts) do vid[i] = em:AddVertex(p - off) end
		for i = 1, #ts, 3 do
			local a, b, c = tonumber(ts[i]) + 1, tonumber(ts[i + 1]) + 1, tonumber(ts[i + 2]) + 1
			local n = (pts[b] - pts[a]):Cross(pts[c] - pts[a])
			if n.Magnitude > 1e-9 then
				local f = em:AddTriangle(vid[a], vid[b], vid[c])
				local nid = em:AddNormal(n.Unit)
				em:SetFaceNormals(f, { nid, nid, nid })
				if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
				HK.Tris += 1
			end
		end
	end)
	if not okB then
		em:Destroy()
		error(errB, 0)
	end
	local okF, fixed = pcall(retry, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	em:Destroy()
	if not okF then error(fixed, 0) end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise })
	end)
	if not ok then
		local ok2, mp2 = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
		if not ok2 then
			fixed:Destroy()
			error(mp2, 0)
		end
		mp = mp2
	end
	keep[#keep + 1] = fixed
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Material, mp.Reflectance = Enum.Material.SmoothPlastic, 0
	return { Part = mp, Off = off, Size = hi - lo }
end

local template = nil                    -- { Fang = the spine grid mesh, Data = { [asset] = { [class] = mesh } } }
local HINGE = Vector3.zero              -- (the helm faceplate's hinge, in the head's space at a head 1.18 tall)
local building = false
local usedAt = 0                        -- (2026-10-26) the last piece made or placed (a kit nobody wears lets go of its meshes)
local releaseHooks = {}                 -- (2026-10-26) the pools of this kit's pieces elsewhere (OnRelease): emptied with it
--- (2026-10-26) `fn()` runs when the kit lets go of its meshes (HydraFX: its resting creatures go with them); never yields
function HK.OnRelease(fn) releaseHooks[#releaseHooks + 1] = fn end
-- THE LIGHT SET (2026-10-23): on Graphics Quality LOW / MEDIUM (phones by default) the kit builds HydraDataLo instead of
-- HydraData -- the same Blender models, silhouettes, colours and seams with about 55% fewer triangles (no sub-pixel edge
-- chamfers, no buried plate undersides, the scale tiles' faces only; side by side the two differ by under 1% of pixels).
-- The set is chosen once the player's settings have loaded; a later quality change rebuilds the other set in the
-- background, swaps it in and bumps HK.Gen (HydraFX rebuilds each resting rig on it once that rig is at rest -- never
-- mid-Vent or mid-pose; per-cast pieces pick the new set up as they are made), and frees the old meshes once no rig
-- reports drawing them (HK.OldSetInUse, set by HydraFX).
HK.Gen, HK.Light = 0, nil
local Settings = nil
local function settings()
	if Settings == nil then
		local ok, m = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings", 5))
		end)
		Settings = (ok and type(m) == "table") and m or false
	end
	return Settings or nil
end
local function wantLight()
	local st = settings()
	local q = st and st.Get and st.Get("GraphicsQuality")
	return type(q) == "number" and q <= 2                         -- (1 LOW, 2 MEDIUM)
end
local function buildSet(light)
	local src = require(script.Parent:WaitForChild(light and "HydraDataLo" or "HydraData", 10))
	local t = { Fang = gridMesh(barbAt, 18, 12), Data = {} }
	for asset, groups in pairs(src.Assets) do
		t.Data[asset] = {}
		for g, d in pairs(groups) do
			t.Data[asset][g] = dataMesh(d.V, d.T)
			task.wait()                                               -- (one mesh a frame: no hitch)
		end
	end
	HINGE = Vector3.new(src.HelmHinge[1], src.HelmHinge[2], src.HelmHinge[3]) / 1000
	return t
end
local function freeSet(t, meshes)
	for _, m in ipairs(meshes) do pcall(function() m:Destroy() end) end
	if t and t.Data then
		for _, groups in pairs(t.Data) do
			for _, g in pairs(groups) do pcall(function() g.Part:Destroy() end) end
		end
	end
	if t and t.Fang then pcall(function() t.Fang.Part:Destroy() end) end   -- (2026-10-26) the spine template too
end
local watching, lightFailed, failedAt = false, nil, 0
local function watchQuality()                                     -- (a quality change: the other set, in the background)
	if watching then return end
	watching = true
	task.spawn(function()
		while true do
			task.wait(1)
			local light = wantLight()
			if lightFailed ~= nil and (light ~= lightFailed or os.clock() - failedAt > 60) then lightFailed = nil end
			if HK.Built and not building and not HK.Failed and light ~= HK.Light and light ~= lightFailed then
				building = true
				local b = budget()
				if b then b.Essential(HK.Id, true) end
				local oldT, oldKeep = template, keep
				keep = {}
				local ok, res = pcall(buildSet, light)
				if ok then
					template, HK.Light, HK.Gen = res, light, HK.Gen + 1
					task.spawn(function()                             -- (per-cast pieces: Patient Zero's are gone in 8 s)
						local t0 = os.clock()
						repeat task.wait(1) until (os.clock() - t0 >= 8 and not (HK.OldSetInUse and HK.OldSetInUse()))
							or os.clock() - t0 > 60
						freeSet(oldT, oldKeep)
					end)
				else
					warn("[HydraKit] the " .. (light and "light" or "full") .. " set did not build (" .. tostring(res) .. "); keeping the current one")
					freeSet(nil, keep)
					keep, lightFailed, failedAt = oldKeep, light, os.clock()
				end
				building = false
				if b then b.Essential(HK.Id, false) end
			end
		end
	end)
end
function HK.Prepare()
	if HK.Built or building or not RunService:IsClient() then return end
	building = true
	local b = budget()
	if b then b.Essential(HK.Id, true) end
	task.spawn(function()
		HK.Tris = 0
		local st = settings()                                     -- (the saved Graphics Quality, not the default)
		local t0 = os.clock()
		while st and st.IsLoaded and not st.IsLoaded() and os.clock() - t0 < 5 do task.wait(0.1) end
		local light = wantLight()
		local ok, res = pcall(buildSet, light)
		if ok then
			template, HK.Light = res, light
			pcall(HK.BuildTex)
			HK.Built = true
			watchQuality()
		else
			HK.Failed = true
			warn("[HydraKit] the meshes did not build (" .. tostring(res) .. "); the Default draws")
			freeSet(nil, keep)
			table.clear(keep)
		end
		building = false
		if b then b.Essential(HK.Id, false) end
	end)
end

----------------------------------------------------------------------------------------------------
-- PAINTED TEXTURES (EditableImages, painted once per client, white: tinted where used)
----------------------------------------------------------------------------------------------------
local function smooth01(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1) return t * t * (3 - 2 * t) end
local function paint(w, h, fn)
	local im = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	local buf = buffer.create(w * h * 4)
	local px = 2 / w
	for y = 0, h - 1 do
		local v = (y + 0.5) / h * 2 - 1
		for x = 0, w - 1 do
			local u = (x + 0.5) / w * 2 - 1
			local a = math.clamp(fn(u, v, px), 0, 1)
			local o = (y * w + x) * 4
			buffer.writeu8(buf, o, 255)
			buffer.writeu8(buf, o + 1, 255)
			buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
		end
		if y % 48 == 47 then task.wait() end
	end
	im:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	return im
end
local function cover(sd, px, glow, reach)
	local c = math.clamp(0.5 - sd / px, 0, 1)
	if glow and sd > 0 then c = math.max(c, glow * math.exp(-sd / reach)) end
	return c
end
local function segDist(x, y, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local t = math.clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)
	local qx, qy = ax + dx * t - x, ay + dy * t - y
	return math.sqrt(qx * qx + qy * qy)
end
local function ringSD(u, v, r, w) return math.abs(math.sqrt(u * u + v * v) - r) - w end

local TEX = nil
function HK.Tex() return TEX or nil end
function HK.BuildTex()
	if TEX ~= nil or not RunService:IsClient() then return end
	TEX = false
	local ok, res = pcall(function()
		local t = {}
		-- THE SIGIL (the hydra's): an outer double ring, a ring of scales, six fangs hooking inward, an inner ring and three
		-- necks coiling out from the centre (the three heads) -- drawn as glowing lines only
		t.Sigil = paint(256, 256, function(u, v, px)
			local r, th = math.sqrt(u * u + v * v), math.atan2(v, u)
			local sd = math.min(ringSD(u, v, 0.94, 0.016), ringSD(u, v, 0.875, 0.007), ringSD(u, v, 0.44, 0.012))
			-- the scales: arcs bulging outward, 18 round
			local a18 = (th / (2 * math.pi) * 18) % 1
			sd = math.min(sd, math.abs(r - (0.7 + 0.05 * math.sin(a18 * math.pi))) - 0.012)
			for i = 0, 5 do
				local a = i / 6 * 2 * math.pi + math.pi / 6
				local ca, sa = math.cos(a), math.sin(a)
				local bx, by = ca * 0.86, sa * 0.86
				local tx, ty = ca * 0.58 + -sa * 0.07, sa * 0.58 + ca * 0.07
				local d = segDist(u, v, bx, by, tx, ty)
				local k = math.clamp(((u - bx) * (tx - bx) + (v - by) * (ty - by)) / 0.0833, 0, 1)
				sd = math.min(sd, d - 0.034 * (1 - k) - 0.004)
			end
			-- three necks: spirals from the centre out to the inner ring, each ending in a small head
			for i = 0, 2 do
				local a0 = i / 3 * 2 * math.pi
				for j = 0, 9 do
					local f0, f1 = j / 10, (j + 1) / 10
					local r0, r1 = 0.06 + 0.3 * f0, 0.06 + 0.3 * f1
					local b0, b1 = a0 + 2.2 * f0, a0 + 2.2 * f1
					sd = math.min(sd, segDist(u, v, math.cos(b0) * r0, math.sin(b0) * r0, math.cos(b1) * r1, math.sin(b1) * r1) - 0.014)
				end
				local hb = a0 + 2.2
				sd = math.min(sd, math.sqrt((u - math.cos(hb) * 0.36) ^ 2 + (v - math.sin(hb) * 0.36) ^ 2) - 0.035)
			end
			return cover(sd, px, 0.28, 0.025) * (1 - smooth01(0.97, 1.0, r))
		end)
		-- THE ETCH: corroded ground -- pitted, blotchy, laced with fine cracks, fading out at its rim
		t.Etch = paint(256, 256, function(u, v)
			local r = math.sqrt(u * u + v * v)
			local n1 = math.noise(u * 4.1, v * 4.1, 0.37)
			local n2 = math.noise(u * 11.3, v * 11.3, 1.91)
			local pits = smooth01(-0.05, 0.25, n1 + 0.45 * n2)
			local crack = math.exp(-math.abs(math.noise(u * 6.7, v * 6.7, 3.3)) / 0.025)
			return math.max(pits * 0.85, crack * 0.9) * (1 - smooth01(0.55, 1.0, r))
		end)
		-- THE CRACK: a network of thin glowing cracks (the Corroded scales on a struck body)
		t.Crack = paint(128, 128, function(u, v)
			local a = math.exp(-math.abs(math.noise(u * 3.2, v * 3.2, 7.7)) / 0.03)
			local b = math.exp(-math.abs(math.noise(u * 6.1, v * 6.1, 2.2)) / 0.025) * 0.6
			return math.max(a, b)
		end)
		-- THE FLAKE: a shed scale chip (an irregular five-sided shard)
		t.Flake = paint(32, 32, function(u, v, px)
			local pts = { { 0.0, -0.9 }, { 0.75, -0.25 }, { 0.5, 0.75 }, { -0.35, 0.85 }, { -0.85, 0.05 } }
			local d, inside = math.huge, false
			for i = 1, #pts do
				local a, b = pts[i], pts[i % #pts + 1]
				d = math.min(d, segDist(u, v, a[1], a[2], b[1], b[2]))
				if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then inside = not inside end
			end
			return cover(inside and -d or d, px)
		end)
		t.Dot = paint(32, 32, function(u, v) return 1 - smooth01(0.15, 1, math.sqrt(u * u + v * v)) end)
		t.Glint = paint(32, 32, function(u, v)
			local au, av = math.abs(u), math.abs(v)
			local star = math.max(math.exp(-au / 0.05) * (1 - av), math.exp(-av / 0.05) * (1 - au))
			return math.max(star, 1 - smooth01(0.0, 0.3, math.sqrt(u * u + v * v)))
		end)
		local out = { Images = t }
		for k2, im in pairs(t) do out[k2] = Content.fromObject(im) end
		return out
	end)
	if ok then TEX = res else warn("[HydraKit] painted textures failed (" .. tostring(res) .. ")") end
end

-- (2026-10-26) THE SHOWCASE CONVENTION: a client-only model no player owns, with the attribute ShowcaseSkin = "<SkinId>"
-- (the Loadout Altar's dummies, the pedestal's held M1), wears that skin -- live and in Studio. Every such model asked
-- about (On) or seen entering the workspace (below) is kept here wherever it sits (the showcases parent theirs in their
-- own folders), so the build starts for it and HydraFX's managers find it until it leaves the workspace.
local showcase = {}
--- whether `m` is a showcase stand-in wearing Hydra (one wearing any skin is kept)
function HK.Showcase(m)
	local id = typeof(m) == "Instance" and m:GetAttribute("ShowcaseSkin")
	if type(id) ~= "string" or Players:GetPlayerFromCharacter(m) then return false end
	-- (2026-10-26) pruned on insert (strong keys): a stand-in that left the workspace goes when the next new one is kept
	if not showcase[m] then
		for k in pairs(showcase) do if not k:IsDescendantOf(workspace) then showcase[k] = nil end end
		showcase[m] = true
	end
	return id == HK.Id
end
--- the showcase stand-ins in the workspace wearing Hydra now
function HK.Showcased()
	local out = {}
	for m in pairs(showcase) do
		if not m:IsDescendantOf(workspace) then
			showcase[m] = nil
		elseif m:GetAttribute("ShowcaseSkin") == HK.Id then
			out[#out + 1] = m
		end
	end
	return out
end

function HK.On(character)
	if typeof(character) ~= "Instance" then return false end
	local on
	if RunService:IsStudio() and character:GetAttribute("StudioSkin") == HK.Id then
		on = true
	elseif HK.Showcase(character) then                             -- (2026-10-26) a showcase stand-in, live too
		on = true
	else
		local plr = Players:GetPlayerFromCharacter(character)
		on = plr ~= nil and plr:GetAttribute("Element") == "Toxin"           -- (a borrowed Toxin Technique: the Default)
			and SkinCatalog.ElementSkin(plr, "Toxin") == HK.Id
	end
	if on and not HK.Failed then HK.Prepare() end
	return on
end
-- (2026-10-26) a showcase stand-in (ShowcaseSkin, live and in Studio) starts the build too, wherever in the workspace it is
if RunService:IsClient() then
	workspace.DescendantAdded:Connect(function(m)
		if m:IsA("Model") then task.defer(function() if m.Parent and HK.Showcase(m) then HK.On(m) end end) end
	end)
end

-- (2026-10-26) THE GIVE-BACK (FrostbladeKit's, for MeshBudget): a built kit nobody here wears right now -- no player is
-- Toxin in this skin (On's own rule; a wearer between bodies, dead or respawning, counts too), no Studio stand-in where
-- HydraFX's manager looks, no showcase stand-in -- and that made or placed no piece for 10 s lets go of every mesh (both
-- sets' templates and fixed meshes), so another skin or wrap that someone does wear can have the budget. Built goes false
-- first, so whatever asks from now on draws the Default; HydraFX drops its resting creatures with it (OnRelease). The
-- next On() that is true builds it again (Prepare). The painted textures (EditableImages, not meshes) stay.
local function wornByPlayer(plr)
	if plr.Character and HK.On(plr.Character) then return true end
	local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Toxin")
	return ok and id == HK.Id and plr:GetAttribute("Element") == "Toxin"
end
local function releaseKit()
	if building or not HK.Built or os.clock() - usedAt < 10 then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if wornByPlayer(plr) then return end
	end
	if RunService:IsStudio() then
		local tg = workspace:FindFirstChild("TrainingGround")
		local dm = tg and tg:FindFirstChild("Dummies")
		for _, list in ipairs({ workspace:GetChildren(), dm and dm:GetChildren() or {} }) do
			for _, m in ipairs(list) do
				if m:IsA("Model") and m:GetAttribute("StudioSkin") == HK.Id then return end
			end
		end
	end
	if #HK.Showcased() > 0 then return end
	HK.Built = false
	for _, fn in ipairs(releaseHooks) do pcall(fn) end
	freeSet(template, keep)
	template, keep = nil, {}
end
--- (2026-10-26) the same let-go without the 10 s idle wait: the Altar showcase calls it on a swap, once the piece that
--- showed this skin is gone (still nothing if a player wears it, a stand-in still shows it, or it is building)
function HK.ReleaseNow()
	usedAt = 0
	releaseKit()
end
if RunService:IsClient() then
	task.spawn(function()
		-- (registered once MeshBudget is there: the lazy getter would otherwise remember it missing for good)
		if script.Parent:WaitForChild("MeshBudget", 10) then
			local b = budget()
			if b then b.Optional(releaseKit) end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- PIECES. Every piece's parts are anchored and placed by a Place function (the caller moves them each frame).
----------------------------------------------------------------------------------------------------
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function sphere(p) local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = p return m end
local function cylinder(p) local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Cylinder m.Parent = p return m end
local function meshCopy(t, name, parent)
	local q = t.Part:Clone()
	q.Name = name
	q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow, q.Massless = true, false, false, false, false, true
	q.Parent = parent
	return q
end
-- a glowing seam ring (a thin Neon disc: only its rim shows, round the joint it sits in)
local function seamRing(parent)
	local s = part({ Name = "Seam", Material = Enum.Material.Neon, Color = HK.Look.Seam, Size = Vector3.new(0.03, 0.3, 0.3) }, parent)
	cylinder(s)
	return s
end

local function glow(name, color, size, parent)                 -- (a Glow-class Neon piece)
	return part({ Name = name, Material = Enum.Material.Neon, Color = color or HK.Look.Glow, Size = size or Vector3.new(0.1, 0.1, 0.1) }, parent)
end
-- the part classes' looks (one MeshPart per class per asset: the class is its colour and material)
local CLASS = {
	Scale = { "Scale" }, Plate = { "ScaleEdge" }, Tile = { "Tile" }, Belly = { "Belly" }, Fang = { "Fang" },
	Frill = { "Frill", 0.3 }, Inner = { "Inner" }, Glow = { "Glow", 0, true }, Core = { "Core", 0, true },
	Glass = { "VenomGlass", 0.4 },                                  -- (SmoothPlastic: Material.Glass would hide the lit core and
	                                                                --  its glow behind it on higher Roblox graphics levels)
}
--- an asset's parts (one per part class): { G = { [class] = part }, T = { [class] = template }, Parts, Base }
local function assetSet(asset, model)
	usedAt = os.clock()                                           -- (2026-10-26) Head / Neck / Helm / Piece
	local set = { G = {}, T = {}, Parts = {}, Base = {} }
	for g, t in pairs(template.Data[asset]) do
		local c = CLASS[g] or CLASS.Scale
		local p = meshCopy(t, asset .. "_" .. g, model)
		p.Color, p.Transparency = HK.Look[c[1]], c[2] or 0
		if c[3] then p.Material = Enum.Material.Neon elseif c[4] then p.Material = c[4] end
		set.G[g], set.T[g] = p, t
		set.Base[p] = c[2] or 0
		table.insert(set.Parts, p)
	end
	return set
end
-- places an asset's parts at `cf` scaled by `k` (a number, or a Vector3 per axis), for one BulkMoveTo
local function placeSet(set, cf, k, outParts, outCFs)
	usedAt = os.clock()                                           -- (2026-10-26) every Place* comes through here
	for g, p in pairs(set.G) do
		local t = set.T[g]
		p.Size = t.Size * k
		outParts[#outParts + 1], outCFs[#outCFs + 1] = p, cf * CFrame.new(t.Off * k)
	end
end
local function fadeSet(set, f)
	for p, base in pairs(set.Base) do p.Transparency = base + (1 - base) * f end
end

--- ONE SERPENT HEAD at `scale` (1: about 1 stud nose to crest; Blender-modelled: HeadSkull + HeadJaw). { Model, Skull,
--- Jaw, Core (the venom gem and throat crystal: Neon), Glow, Parts, S }; nil until built.
function HK.Head(scale, parent)
	if not (template and template.Data) then return nil end
	local model = Instance.new("Model")
	model.Name = "HydraHead"
	local h = { Model = model, S = scale or 1, Skull = assetSet("HeadSkull", model), Jaw = assetSet("HeadJaw", model), Parts = {} }
	for _, p in ipairs(h.Skull.Parts) do table.insert(h.Parts, p) end
	for _, p in ipairs(h.Jaw.Parts) do table.insert(h.Parts, p) end
	h.Core, h.Glow = h.Skull.G.Core, h.Skull.G.Glow
	if parent then model.Parent = parent end
	return h
end

--- Poses a head: `cf` is its hinge (the jaw's, at the back of the skull; -Z forward, +Y up); `jaw` opens the lower jaw
--- (radians, 0 shut); `fade` 0..1. Appends parts and CFrames for one BulkMoveTo.
function HK.PlaceHead(h, cf, jaw, fade, outParts, outCFs)
	placeSet(h.Skull, cf, h.S, outParts, outCFs)
	placeSet(h.Jaw, cf * CFrame.Angles(-(jaw or 0), 0, 0), h.S, outParts, outCFs)
	local f = math.clamp(fade or 0, 0, 1)
	if f ~= h.LastFade then
		h.LastFade = f
		fadeSet(h.Skull, f)
		fadeSet(h.Jaw, f)
	end
end

--- THE NECK at `scale`: `n` armoured segments (Blender-modelled NeckSeg: body, dorsal plate and keel, a spike, belly
--- scutes, a Glow seam and throat vein), tapering base to head. { Model, Segs = { { Set, Vein, W } }, Parts, S }
HK.NeckWidth = 0.5
HK.Overlap = 1.06
function HK.Neck(scale, n, parent)
	if not (template and template.Data) then return nil end
	local model = Instance.new("Model")
	model.Name = "HydraNeck"
	local segs, parts = {}, {}
	for i = 1, n do
		local set = assetSet("NeckSeg", model)
		segs[i] = { Set = set, Vein = set.G.Glow, W = 1 - 0.22 * (i - 1) / math.max(1, n - 1) }
		for _, p in ipairs(set.Parts) do table.insert(parts, p) end
	end
	if parent then model.Parent = parent end
	return { Model = model, Segs = segs, Parts = parts, S = scale or 1 }
end

--- Lays a neck along `curve` (s 0..1 -> a world point, base to head). `side` (a world vector square to the bend) rolls
--- the segments: the keel (+Y) faces side x tangent. Returns the end frame (-Z along the curve: a head's hinge goes there).
local SAMPLES = 32
function HK.PlaceNeck(neck, curve, side, outParts, outCFs)
	local s = neck.S
	local pts, cum = {}, {}
	cum[0] = 0
	for i = 0, SAMPLES do pts[i] = curve(i / SAMPLES) end
	for i = 1, SAMPLES do cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	local total = math.max(1e-3, cum[SAMPLES])
	local function at(f)
		local d = math.clamp(f, 0, 1) * total
		local i = 1
		while i < SAMPLES and cum[i] < d do i += 1 end
		local a, b = pts[i - 1], pts[i]
		local k = math.clamp((d - cum[i - 1]) / math.max(1e-6, cum[i] - cum[i - 1]), 0, 1)
		local tan = b - a
		return a:Lerp(b, k), (tan.Magnitude > 1e-6) and tan.Unit or Vector3.yAxis
	end
	local function frame(pos, tan)
		local up = side:Cross(tan)
		if up.Magnitude < 1e-3 then up = Vector3.yAxis:Cross(tan) end
		if up.Magnitude < 1e-3 then up = Vector3.xAxis end
		return CFrame.lookAt(pos, pos + tan, up.Unit)
	end
	local n = #neck.Segs
	for i, sg in ipairs(neck.Segs) do
		local f0, f1 = (i - 1) / n, i / n
		local pos, tan = at((f0 + f1) / 2)
		local wid = HK.NeckWidth * s * sg.W
		placeSet(sg.Set, frame(pos, tan), Vector3.new(wid, wid, (f1 - f0) * total * HK.Overlap), outParts, outCFs)
	end
	local ep, et = at(1)
	return frame(ep, et), total
end

--- THE HELM (the Vent; Blender-modelled, hard-surface): HelmBack, worn always (the shell -- crown, sides, back, the chin
--- guard -- scale plates, the fang crest, the serpent engravings, the outer hinge knuckles) and HelmFace, the FACEPLATE:
--- ONE rigid piece on ONE hinge at the top front of the head (the fang brow plate, the lit eye-slits under its edge,
--- cheek scales, the mouth seam). `scale` 1 fits a head 1.18 tall. { Model, Back, Face, Parts, S }
function HK.Helm(scale, parent)
	if not (template and template.Data) then return nil end
	local model = Instance.new("Model")
	model.Name = "HydraHelm"
	local h = { Model = model, S = scale or 1, Back = assetSet("HelmBack", model), Face = assetSet("HelmFace", model), Parts = {} }
	for _, p in ipairs(h.Back.Parts) do table.insert(h.Parts, p) end
	for _, p in ipairs(h.Face.Parts) do table.insert(h.Parts, p) end
	h.Slit = h.Face.G.Glow
	if parent then model.Parent = parent end
	return h
end

--- Poses the helm on a head (`headCF`, its height `hs`): `open` 0 = the faceplate shut flush on the shell, 1 = swung up
--- on its one hinge to stand above the forehead, leaning back (a visor flipped up). The shell never moves. Returns the
--- hinge's frame.
HK.HelmOpen = math.rad(195)
function HK.PlaceHelm(h, headCF, hs, open, outParts, outCFs)
	local k = hs / 1.18 * h.S
	placeSet(h.Back, headCF, k, outParts, outCFs)
	local hcf = headCF * CFrame.new(HINGE * k) * CFrame.Angles(HK.HelmOpen * math.clamp(open, -0.02, 1.08), 0, 0)
	placeSet(h.Face, hcf, k, outParts, outCFs)
	return hcf
end

--- ONE ASSET as a piece (the baked clips' neck segments): { Model, Set, Parts }; nil until built
function HK.Piece(asset, parent)
	if not (template and template.Data and template.Data[asset]) then return nil end
	local model = Instance.new("Model")
	model.Name = "Hydra" .. asset
	local set = assetSet(asset, model)
	if parent then model.Parent = parent end
	return { Model = model, Set = set, Parts = set.Parts }
end
--- Places a set (a Piece's, or a Head's Skull / Jaw) at `cf` scaled by `k` (a number or a per-axis Vector3)
function HK.PlaceSet(set, cf, k, outParts, outCFs) placeSet(set, cf, k, outParts, outCFs) end

--- THE BAKED CLIPS (2026-10-23): the approved Blender animations (HydraAnimData: Patient Zero, the kill effect), decoded
--- once per client. HK.Clip(name) -> { Fps, N, Duration, Pieces = { { Name, Asset, T = { ints } } } }; HK.Sample(piece,
--- clip, t) -> the piece's CFrame (relative to the clip's anchor) and its per-axis scale at clip time t.
local clips = nil
function HK.Clip(name)
	if clips == nil then
		local ok, src = pcall(function() return require(script.Parent:WaitForChild("HydraAnimData", 10)) end)
		clips = {}
		if ok and type(src) == "table" then
			for n, c in pairs(src) do
				local out = { Fps = c.Fps, N = c.N, Duration = c.Duration, Pieces = {} }
				for _, pc in ipairs(c.Pieces) do
					local T = {}
					for _, v in ipairs(string.split(pc.T, ",")) do T[#T + 1] = tonumber(v) end
					out.Pieces[#out.Pieces + 1] = { Name = pc.Name, Asset = pc.Asset, T = T }
				end
				clips[n] = out
			end
		end
	end
	return clips[name]
end
function HK.Sample(pc, clip, t)
	local x = math.clamp(t * clip.Fps, 0, clip.N - 1)
	local i = math.floor(x)
	local f = x - i
	local a, b = i * 10, math.min(i + 1, clip.N - 1) * 10
	local T = pc.T
	local function v(k) return T[a + k] + (T[b + k] - T[a + k]) * f end
	local bw, bx, by, bz = T[b + 4], T[b + 5], T[b + 6], T[b + 7]
	if T[a + 4] * bw + T[a + 5] * bx + T[a + 6] * by + T[a + 7] * bz < 0 then bw, bx, by, bz = -bw, -bx, -by, -bz end
	local qw = T[a + 4] + (bw - T[a + 4]) * f
	local qx = T[a + 5] + (bx - T[a + 5]) * f
	local qy = T[a + 6] + (by - T[a + 6]) * f
	local qz = T[a + 7] + (bz - T[a + 7]) * f
	local m = math.sqrt(qw * qw + qx * qx + qy * qy + qz * qz)
	if m < 1e-6 then m, qw = 1, 1 end
	return CFrame.new(v(1) / 100, v(2) / 100, v(3) / 100, qx / m, qy / m, qz / m, qw / m),
		Vector3.new(v(8), v(9), v(10)) / 1000
end

--- THE M1 GLOB: venom glass round a Core, a Glow seam. { Part, Core, Seam }
function HK.Glob(parent)
	local L = HK.Look
	local g = part({ Name = "Glob", Color = L.Glass, Transparency = 0.3, Reflectance = 0.12, Size = Vector3.new(0.6, 0.6, 0.6) }, parent)
	sphere(g)
	local c = glow("GlobCore", L.Core, Vector3.new(0.3, 0.3, 0.3), parent)
	sphere(c)
	local seam = seamRing(parent)
	return { Part = g, Core = c, Seam = seam }
end

--- A lone FANG (Acid Rain's spines). { Part, Seam?, K }
local BARB_TIP = barbCentre(1)
function HK.Barb(length, thick, parent, withSeam)
	if not (template and template.Fang) then return nil end
	usedAt = os.clock()                                           -- (2026-10-26)
	local TB = template.Fang
	local b = meshCopy(TB, "Spine", parent)
	b.Color = HK.Look.Fang
	local k = length / 0.85
	b.Size = TB.Size * k * Vector3.new(thick, thick, 1)
	local seam = withSeam and seamRing(parent) or nil
	-- (2026-10-26) T: its template (Off / Size), kept with it -- a spine still falling when the kit lets go places on
	return { Part = b, Seam = seam, K = Vector3.new(k * thick, k * thick, k), T = TB }
end
function HK.BarbCF(barb, baseCF)
	usedAt = os.clock()                                           -- (2026-10-26)
	return baseCF * CFrame.new((barb.T or template.Fang).Off * barb.K)
end
function HK.BarbTipLocal() return BARB_TIP end

return HK
