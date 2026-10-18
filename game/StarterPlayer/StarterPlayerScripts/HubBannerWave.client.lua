--[[
	HubBannerWave (LocalScript, StarterPlayerScripts) -- 2026-10-15, on request: the Arcane Observatory hub's hanging
	banners wave like cloth.

	The 11 banners are triangles inside the hub's merged meshes: the cloth in Visual.OBS_Cloth_Navy_01 /
	OBS_Cloth_White_01 (one 744-triangle piece per banner) and their gold borders and emblems in OBS_Trim_Gold_01 / 02.
	Meshes cannot be published from a script in this place (CreateAssetAsync is not available), so on this client:
	  * the four meshes are loaded once as EditableMeshes (no copies) and shown by local MeshParts standing exactly where
	    the originals stand; the originals are hidden locally (and again if streaming brings them back);
	  * each banner is found from its cloth piece (its width, its facing and its top), and every vertex of those four
	    meshes that lies on the banner -- cloth, border, emblem -- is tied to it;
	  * a few times a second (WaveHz) the nearby banners' vertices are moved: a slow wave runs down from the rod (pinned
	    at the top, growing toward the hem) with a gentle sideways sway, each banner on its own phase and tempo, so the
	    border and the emblem ripple with the cloth.
	If anything fails the originals are shown again and the banners simply hang still. Nothing changes on the server.
]]

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Cloth = { "OBS_Cloth_Navy_01", "OBS_Cloth_White_01" },
	Riders = { "OBS_Trim_Gold_01", "OBS_Trim_Gold_02" },   -- meshes whose triangles ride on the banners
	MinBannerFaces = 200,                -- a cloth piece this big is a banner (the rod caps are 32)
	Slack = { Normal = 0.15, Width = 0.1, Below = 0.1, Above = 0.05 },   -- studs past the cloth that still rides it
	Amplitude = 0.32,                    -- studs, at the hem
	Waves = 0.9,                         -- wave crests along the banner's height
	Speed = 1.8,                         -- radians a second (slow)
	Sway = 0.12,                         -- studs of sideways sway at the hem
	Across = 0.6,                        -- radians of phase across the width (the hem's corners lag each other)
	-- the gold border and emblem lie a hair above the cloth; the cloth's big triangles bend a little differently from
	-- their denser ones, so waving, the cloth poked through them and the border seemed not to move (2026-10-15).
	-- While a banner waves its riders stand this far further out on their own side (0 at the rod, full a little below).
	RiderLift = 0.06,
	Tempo = { 0.8, 1.2 },
	Near = 110,                          -- only banners this close to the camera move
	WaveHz = 30,                         -- updates a second
}

local hub = workspace:WaitForChild(Tuning.Hub, 60)
local visual = hub and hub:WaitForChild("Visual", 60)
if not visual then return end

local folder = Instance.new("Folder")
folder.Name = "HubBannerWave"
folder.Parent = workspace

local meshes = {}      -- [name] = { Source, Em, CF, Scale, Shown }
local banners = {}     -- { Centre, U, N, Top, Height, Phase, Tempo, Verts = { {Em, Id, Rest, H, W} }, Moving }
local hidden = {}

local function hide(part)
	if hidden[part.Name] and part:IsA("BasePart") then part.Transparency = 1 end
end

local function world(m, p) return m.CF:PointToWorldSpace(p * m.Scale) end

local function load(name)
	local src = visual:WaitForChild(name, 120)
	if not (src and src:IsA("MeshPart")) then error(name .. " never arrived") end
	local em = AssetService:CreateEditableMeshAsync(src.MeshContent)
	local m = { Source = src, Em = em, CF = src.CFrame, Scale = src.Size / src.MeshSize, Name = name }
	meshes[name] = m
	return m
end

-- a mesh's connected pieces (triangles sharing a vertex id or a vertex position): { { Verts = {...}, Faces = n } }
local function piecesOf(em)
	local parent, key = {}, {}
	local function find(a)
		while parent[a] ~= a do
			parent[a] = parent[parent[a]]
			a = parent[a]
		end
		return a
	end
	for _, v in ipairs(em:GetVertices()) do
		parent[v] = v
		local q = em:GetPosition(v)
		local k = string.format("%.2f,%.2f,%.2f", q.X, q.Y, q.Z)
		if key[k] then parent[find(v)] = find(key[k]) else key[k] = v end
	end
	local faces = {}
	for _, f in ipairs(em:GetFaces()) do
		local vs = em:GetFaceVertices(f)
		for i = 2, #vs do
			local a, b = find(vs[1]), find(vs[i])
			if a ~= b then parent[b] = a end
		end
	end
	for _, f in ipairs(em:GetFaces()) do
		local r = find(em:GetFaceVertices(f)[1])
		faces[r] = (faces[r] or 0) + 1
	end
	local byRoot, list = {}, {}
	for i, v in ipairs(em:GetVertices()) do
		local r = find(v)
		local p = byRoot[r]
		if not p then
			p = { Verts = {}, Faces = faces[r] or 0 }
			byRoot[r] = p
			list[#list + 1] = p
		end
		table.insert(p.Verts, v)
		if i % 6000 == 0 then task.wait() end
	end
	return list
end

-- the banners in one cloth mesh: its pieces of at least MinBannerFaces
local function findBanners(m)
	local em = m.Em
	for _, piece in ipairs(piecesOf(em)) do
		if piece.Faces < Tuning.MinBannerFaces then continue end
		local verts = piece.Verts
		-- the banner's frame: its width axis U (the long horizontal spread), its facing N, its top and height
		local lo, hi, sum = Vector3.one * math.huge, -Vector3.one * math.huge, Vector3.zero
		local pts = table.create(#verts)
		for i, v in ipairs(verts) do
			local p = world(m, em:GetPosition(v))
			pts[i] = p
			lo, hi, sum = lo:Min(p), hi:Max(p), sum + p
		end
		local c = sum / #pts
		local sxx, sxz, szz = 0, 0, 0
		for _, p in ipairs(pts) do
			local dx, dz = p.X - c.X, p.Z - c.Z
			sxx += dx * dx; sxz += dx * dz; szz += dz * dz
		end
		local angle = 0.5 * math.atan2(2 * sxz, sxx - szz)
		local u = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local n = Vector3.new(-u.Z, 0, u.X)
		local halfW, halfT = 0, 0
		for _, p in ipairs(pts) do
			halfW = math.max(halfW, math.abs((p - c):Dot(u)))
			halfT = math.max(halfT, math.abs((p - c):Dot(n)))
		end
		local i = #banners + 1
		banners[i] = {
			Centre = c, U = u, N = n, HalfW = halfW, HalfT = halfT, Top = hi.Y, Bottom = lo.Y,
			Height = math.max(hi.Y - lo.Y, 1), Phase = i * 2.39, Tempo = Tuning.Tempo[1] + (Tuning.Tempo[2] - Tuning.Tempo[1])
				* ((i * 0.618) % 1), Verts = {}, Moving = false,
		}
	end
end

local function bannerAt(p)
	local S = Tuning.Slack
	for _, b in ipairs(banners) do
		if p.Y >= b.Bottom - S.Below and p.Y <= b.Top + S.Above then
			local d = p - b.Centre
			if math.abs(d:Dot(b.N)) <= b.HalfT + S.Normal and math.abs(d:Dot(b.U)) <= b.HalfW + S.Width then return b end
		end
	end
	return nil
end

-- every PIECE of a mesh whose centre lies on a banner is tied to it whole -- the cloth, its border, its emblem -- so no
-- triangle is ever half moved (vertex by vertex, 348 triangles tore: a wall trim strip runs behind some banners)
local function tie(m)
	local em = m.Em
	for _, piece in ipairs(piecesOf(em)) do
		local sum = Vector3.zero
		local pts = table.create(#piece.Verts)
		for i, v in ipairs(piece.Verts) do
			pts[i] = em:GetPosition(v)
			sum += world(m, pts[i])
		end
		local b = bannerAt(sum / #piece.Verts)
		if b then
			for i, v in ipairs(piece.Verts) do
				local p = world(m, pts[i])
				table.insert(b.Verts, {
					Em = em, Id = v, Rest = pts[i], Mesh = m,
					H = math.clamp((b.Top - p.Y) / b.Height, 0, 1),
					W = math.clamp((p - b.Centre):Dot(b.U) / math.max(b.HalfW, 0.1), -1, 1),
				})
			end
		end
	end
end

local function show(m)
	local src = m.Source
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(m.Em))
	part.Name = src.Name .. "_Waving"
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Material, part.MaterialVariant = src.Material, src.MaterialVariant
	part.Color, part.Transparency, part.Reflectance = src.Color, src.Transparency, src.Reflectance
	part.CastShadow = src.CastShadow
	part.Size, part.CFrame = src.Size, src.CFrame
	m.Shown = part
	return part
end

local function undo()
	for name, m in pairs(meshes) do
		hidden[name] = nil
		if m.Shown then m.Shown:Destroy() end
		if m.Source and m.Source.Parent then m.Source.Transparency = 0 end
		m.Em:Destroy()
	end
	table.clear(meshes)
	table.clear(banners)
end

local ready = false
task.spawn(function()
	local ok, err = pcall(function()
		for _, name in ipairs(Tuning.Cloth) do findBanners(load(name)) end
		for _, name in ipairs(Tuning.Riders) do load(name) end
		for _, m in pairs(meshes) do tie(m) end
		-- each rider vertex's side of the cloth (+1 in front along N, -1 behind): from the nearest cloth vertex of its
		-- banner, so a border on a bowed banner's edge is lifted off the face it actually lies on
		local clothSet = {}
		for _, n in ipairs(Tuning.Cloth) do clothSet[n] = true end
		for _, b in ipairs(banners) do
			local buckets = {}
			for _, v in ipairs(b.Verts) do
				if clothSet[v.Mesh.Name] then
					local p = world(v.Mesh, v.Rest)
					local k = math.floor(p.Y * 4)
					buckets[k] = buckets[k] or {}
					table.insert(buckets[k], p)
				end
			end
			for _, v in ipairs(b.Verts) do
				if not clothSet[v.Mesh.Name] then
					local p = world(v.Mesh, v.Rest)
					local k = math.floor(p.Y * 4)
					local best, bd = nil, math.huge
					for kk = k - 1, k + 1 do
						for _, q in ipairs(buckets[kk] or {}) do
							local d = (q - p).Magnitude
							if d < bd then best, bd = q, d end
						end
					end
					v.Side = best and ((p - best):Dot(b.N) >= 0 and 1 or -1) or 0
				end
			end
			-- the banner's knots: 0, 1 and the heights (as H) its gold has vertices at -- except any height that falls
			-- INSIDE one of its gold edges: a long straight border strip (one edge from H .3 to .8, say) cannot bend
			-- in the middle, so nothing on the banner may bend there either; it bends only where the gold can
			local spans = {}
			local byId = {}
			for _, v in ipairs(b.Verts) do
				if not clothSet[v.Mesh.Name] then
					byId[v.Em] = byId[v.Em] or {}
					byId[v.Em][v.Id] = v.H
				end
			end
			for emk, ids in pairs(byId) do
				for _, fc in ipairs(emk:GetFaces()) do
					local vs = emk:GetFaceVertices(fc)
					local h1, h2, h3 = ids[vs[1]], ids[vs[2]], ids[vs[3]]
					if h1 and h2 and h3 then
						local lo3, hi3 = math.min(h1, h2, h3), math.max(h1, h2, h3)
						if hi3 - lo3 > 0.01 then spans[#spans + 1] = { lo3, hi3 } end
					end
				end
			end
			local knots = { 0, 1 }
			for _, v in ipairs(b.Verts) do
				if not clothSet[v.Mesh.Name] then knots[#knots + 1] = v.H end
			end
			table.sort(knots)
			local uniq = {}
			for _, k in ipairs(knots) do
				if #uniq == 0 or k - uniq[#uniq] > 0.004 then
					local inside = false
					for _, s in ipairs(spans) do
						if k > s[1] + 0.004 and k < s[2] - 0.004 then inside = true; break end
					end
					if not inside or k == 0 or k == 1 then uniq[#uniq + 1] = k end
				end
			end
			b.Knots = #uniq
			for _, v in ipairs(b.Verts) do
				local lo, hi = 1, #uniq
				while hi - lo > 1 do
					local mid = (lo + hi) // 2
					if uniq[mid] <= v.H then lo = mid else hi = mid end
				end
				local k0, k1 = uniq[lo], uniq[hi]
				v.K0, v.K1 = k0, k1
				v.KF = k1 > k0 and math.clamp((v.H - k0) / (k1 - k0), 0, 1) or 0
			end
			task.wait()
		end
		-- self-check (read by tests through the folder's attributes): a triangle with only some corners tied would
		-- tear; report how many, and how far down the banner the worst one is (0 = at the rod, where nothing moves)
		local tied = {}
		local count = 0
		for _, b in ipairs(banners) do
			for _, v in ipairs(b.Verts) do
				tied[v.Em] = tied[v.Em] or {}
				tied[v.Em][v.Id] = v.H
				count += 1
			end
		end
		local torn, worst = 0, 0
		for _, m in pairs(meshes) do
			local t = tied[m.Em] or {}
			for _, f in ipairs(m.Em:GetFaces()) do
				local n, h = 0, 0
				local vs = m.Em:GetFaceVertices(f)
				for _, v in ipairs(vs) do
					if t[v] then n += 1; h = math.max(h, t[v]) end
				end
				if n > 0 and n < #vs then torn += 1; worst = math.max(worst, h) end
			end
		end
		local ks = {}
		for _, b in ipairs(banners) do ks[#ks + 1] = tostring(b.Knots or 0) end
		folder:SetAttribute("Knots", table.concat(ks, " "))   -- bend points per banner (for tests)
		folder:SetAttribute("Banners", #banners)
		folder:SetAttribute("TiedVerts", count)
		folder:SetAttribute("TornFaces", torn)
		folder:SetAttribute("TornWorstH", worst)
		-- swap in the local copies all at once
		for name, m in pairs(meshes) do
			show(m).Parent = folder
			hidden[name] = true
			hide(m.Source)
		end
	end)
	if not ok then
		warn("[HubBannerWave] the banners stay still: " .. tostring(err))
		undo()
		return
	end
	visual.ChildAdded:Connect(hide)
	ready = true
end)

local t0, acc = os.clock(), 0
RunService.Heartbeat:Connect(function(dt)
	if not ready then return end
	acc += dt
	if acc < 1 / Tuning.WaveHz then return end
	acc = 0
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local t = os.clock() - t0
	local A, K, Sw, Ac = Tuning.Amplitude, Tuning.Waves * 2 * math.pi, Tuning.Sway, Tuning.Across
	local lift = Tuning.RiderLift
	local moving = 0
	for _, b in ipairs(banners) do
		local near = (b.Centre - eye).Magnitude <= Tuning.Near
		if near then
			local tt = t * Tuning.Speed * b.Tempo
			local sway = Sw * math.sin(tt * 0.7 + b.Phase * 1.7)
			-- the bend is worked out at the banner's KNOTS (the heights its gold has vertices at) and drawn straight
			-- between them, for the cloth too: the border's side strips are long straight segments, so a smooth cloth
			-- bent away from them and slipped out from under the border (2026-10-15)
			local function bend(h, w)
				return A * h ^ 1.4 * math.sin(K * h - tt + b.Phase + Ac * w)
			end
			for _, v in ipairs(b.Verts) do
				local h0, h1, f = v.K0, v.K1, v.KF
				local a = bend(h0, v.W) + (bend(h1, v.W) - bend(h0, v.W)) * f
				local sw = sway * (h0 * h0 + (h1 * h1 - h0 * h0) * f)
				local s = v.H ^ 1.4
				local d = b.N * (a + (v.Side or 0) * lift * math.min(1, s * 12)) + b.U * sw
				v.Em:SetPosition(v.Id, v.Rest + v.Mesh.CF:VectorToObjectSpace(d) / v.Mesh.Scale)
			end
			b.Moving = true
			moving += 1
		elseif b.Moving then
			for _, v in ipairs(b.Verts) do v.Em:SetPosition(v.Id, v.Rest) end   -- back to hanging still
			b.Moving = false
		end
	end
	if folder:GetAttribute("Moving") ~= moving then folder:SetAttribute("Moving", moving) end   -- for tests
end)
