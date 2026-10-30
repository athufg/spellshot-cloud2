-- analyse_map.luau: structural metrics for one duel map, read only, from its collision (whatever CanCollide parts the
-- map holds; Visual meshes, triggers and marks don't collide). Returns a JSON string. Usage: loadstring(src)()(MapName)
--   floor scan   4-stud columns; every walkable surface (normal.Y > 0.7, 5.2 studs of headroom) is a node
--   tiers        relative to the spawn marks' floor G: ground [-3, 4), mid [4, 16), high >= 16, below < -3
--   walk graph   neighbouring nodes within 2.6 studs of height, chest-height ray between them clear (walking only:
--                no jumps, wall runs or drops, so it under-counts what the movement kit can do)
--   routes       shortest A->B walk path, then remove a 12-stud corridor round it (beyond 24 studs of each spawn)
--                and repeat: the count is how many walking routes exist that are at least ~24 studs apart
--   sightlines   eye-height (4.5) visibility between sampled ground/mid positions; "long" = 100+ studs apart
--   centre cover share of the central third's columns blocked by collision at waist (3) / head (4.5) height
--   symmetry     share of ground-tier columns matched by the point reflection through the spawns' midpoint, and by
--                the mirror across the perpendicular bisector of A-B
return function(MAPNAME)
	local HttpService = game:GetService("HttpService")
	local map = assert(workspace:FindFirstChild(MAPNAME), "no " .. MAPNAME)
	local marks = map:FindFirstChild("Marks")
	local A, B = marks and marks:FindFirstChild("A"), marks and marks:FindFirstChild("B")
	assert(A and B, MAPNAME .. " has no A/B marks")
	A, B = A.Position, B.Position
	local CELL = 4
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { map }
	rp.RespectCanCollide = true
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { map }
	op.RespectCanCollide = true
	local rays = 0
	local function cast(o, d)
		rays += 1
		if rays % 4000 == 0 then task.wait() end
		return workspace:Raycast(o, d, rp)
	end

	-- bounds from colliding parts (no backdrop, nothing absurdly large)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in ipairs(map:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide and not p:FindFirstAncestor("Backdrop") and p.Size.Magnitude < 2500 then
			local cf, s = p.CFrame, p.Size / 2
			for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }) do
				local w = cf * (s * c)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	local G = (A.Y + B.Y) / 2 - 0.3
	local nx, nz = math.ceil((hi.X - lo.X) / CELL), math.ceil((hi.Z - lo.Z) / CELL)
	local function cx(ix) return lo.X + (ix + 0.5) * CELL end
	local function cz(iz) return lo.Z + (iz + 0.5) * CELL end

	-- floor scan
	local nodes, col = {}, {}
	local wlo, whi = Vector2.new(1e9, 1e9), Vector2.new(-1e9, -1e9)
	for ix = 0, nx - 1 do
		col[ix] = {}
		for iz = 0, nz - 1 do
			local px, pz = cx(ix), cz(iz)
			local y = hi.Y + 5
			local list = {}
			for _ = 1, 6 do
				local r = cast(Vector3.new(px, y, pz), Vector3.new(0, -(y - lo.Y + 5), 0))
				if not r then break end
				if r.Normal.Y > 0.7 and not cast(r.Position + Vector3.new(0, 0.05, 0), Vector3.new(0, 5.2, 0)) then
					local dy = r.Position.Y - G
					local tier = dy < -3 and "below" or dy < 4 and "ground" or dy < 16 and "mid" or "high"
					table.insert(nodes, { ix = ix, iz = iz, y = r.Position.Y, tier = tier })
					table.insert(list, #nodes)
					if tier ~= "below" then
						wlo = Vector2.new(math.min(wlo.X, px), math.min(wlo.Y, pz))
						whi = Vector2.new(math.max(whi.X, px), math.max(whi.Y, pz))
					end
				end
				y = r.Position.Y - 0.05
			end
			col[ix][iz] = list
		end
	end

	-- walk graph
	local adj = {}
	for i = 1, #nodes do adj[i] = {} end
	for i, n in ipairs(nodes) do
		for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
			local c = col[n.ix + d[1]] and col[n.ix + d[1]][n.iz + d[2]]
			if c then
				for _, j in ipairs(c) do
					local m = nodes[j]
					if math.abs(m.y - n.y) <= 2.6 then
						local h = math.max(m.y, n.y) + 2.5
						local a, b = Vector3.new(cx(n.ix), h, cz(n.iz)), Vector3.new(cx(m.ix), h, cz(m.iz))
						if not cast(a, b - a) then
							table.insert(adj[i], j)
							table.insert(adj[j], i)
						end
					end
				end
			end
		end
	end

	local function nearestNode(p)
		local best, bd
		local ix0, iz0 = math.floor((p.X - lo.X) / CELL), math.floor((p.Z - lo.Z) / CELL)
		for r = 0, 3 do
			for ix = ix0 - r, ix0 + r do
				for iz = iz0 - r, iz0 + r do
					for _, j in ipairs((col[ix] and col[ix][iz]) or {}) do
						local n = nodes[j]
						local d = (Vector3.new(cx(n.ix), n.y, cz(n.iz)) - p).Magnitude
						if not bd or d < bd then best, bd = j, d end
					end
				end
			end
			if best then return best end
		end
	end
	local sA, sB = nearestNode(A), nearestNode(B)

	local function bfs(removed)
		local prev, q, head = { [sA] = 0 }, { sA }, 1
		while head <= #q do
			local i = q[head]
			head += 1
			if i == sB then
				local path, k = {}, sB
				while k ~= 0 do table.insert(path, k); k = prev[k] end
				return path
			end
			for _, j in ipairs(adj[i]) do
				if prev[j] == nil and not removed[j] then
					prev[j] = i
					table.insert(q, j)
				end
			end
		end
	end
	local routes, removed = {}, {}
	for _ = 1, 6 do
		local path = sA and sB and bfs(removed)
		if not path then break end
		table.insert(routes, #path * CELL)
		for _, id in ipairs(path) do
			local n = nodes[id]
			local p = Vector2.new(cx(n.ix), cz(n.iz))
			if (p - Vector2.new(A.X, A.Z)).Magnitude > 24 and (p - Vector2.new(B.X, B.Z)).Magnitude > 24 then
				for dx = -3, 3 do
					for dz = -3, 3 do
						if dx * dx + dz * dz <= 9 then
							for _, j in ipairs((col[n.ix + dx] and col[n.ix + dx][n.iz + dz]) or {}) do
								if math.abs(nodes[j].y - n.y) < 8 then removed[j] = true end
							end
						end
					end
				end
			end
		end
	end

	-- sightlines between sampled ground/mid positions (about 320 samples)
	local pool = {}
	for i, n in ipairs(nodes) do
		if n.tier == "ground" or n.tier == "mid" then table.insert(pool, i) end
	end
	local step = math.max(1, math.floor(#pool / 320))
	local samp = {}
	for k = 1, #pool, step do table.insert(samp, nodes[pool[k]]) end
	local function eye(n) return Vector3.new(cx(n.ix), n.y + 4.5, cz(n.iz)) end
	local longPairs, longVisible, maxVisible = 0, 0, 0
	for a = 1, #samp do
		local pa = eye(samp[a])
		for b = a + 1, #samp do
			local pb = eye(samp[b])
			local d = (pb - pa).Magnitude
			if d >= 100 then
				longPairs += 1
				if not cast(pa, pb - pa) then
					longVisible += 1
					maxVisible = math.max(maxVisible, d)
				end
			end
		end
	end
	local function exposure(s)
		local seen = 0
		for _, n in ipairs(samp) do
			local pn = eye(n)
			if not cast(s, pn - s) then seen += 1 end
		end
		return math.floor(seen / math.max(1, #samp) * 100 + 0.5)
	end
	local eA, eB = A + Vector3.new(0, 4.2, 0), B + Vector3.new(0, 4.2, 0)

	-- centre cover and void, central third of the walkable bounds
	local cw = (whi - wlo) / 3
	local cmin, cmax = wlo + cw, whi - cw
	local cells, head, waist, void = 0, 0, 0, 0
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local px, pz = cx(ix), cz(iz)
			if px >= cmin.X and px <= cmax.X and pz >= cmin.Y and pz <= cmax.Y then
				cells += 1
				local hasGround = false
				for _, j in ipairs(col[ix][iz]) do if nodes[j].tier == "ground" then hasGround = true end end
				if #workspace:GetPartBoundsInBox(CFrame.new(px, G + 4.5, pz), Vector3.new(1, 1, 1), op) > 0 then head += 1 end
				if #workspace:GetPartBoundsInBox(CFrame.new(px, G + 3, pz), Vector3.new(1, 1, 1), op) > 0 then waist += 1 end
				if not hasGround and #col[ix][iz] == 0 then void += 1 end
			end
		end
	end

	-- tiers by area, and symmetry of the ground tier
	local tierN = { below = 0, ground = 0, mid = 0, high = 0 }
	local groundAt = {}
	for _, n in ipairs(nodes) do
		tierN[n.tier] += 1
		if n.tier == "ground" then groundAt[n.ix .. "," .. n.iz] = true end
	end
	local M = Vector2.new((A.X + B.X) / 2, (A.Z + B.Z) / 2)
	local u = (Vector2.new(B.X, B.Z) - Vector2.new(A.X, A.Z)).Unit
	local gTotal, pointHit, mirrorHit = 0, 0, 0
	local function has(p)
		local ix, iz = math.floor((p.X - lo.X) / CELL), math.floor((p.Y - lo.Z) / CELL)
		for dx = -1, 1 do for dz = -1, 1 do if groundAt[(ix + dx) .. "," .. (iz + dz)] then return true end end end
		return false
	end
	for key in pairs(groundAt) do
		local ix, iz = string.match(key, "(-?%d+),(-?%d+)")
		local p = Vector2.new(cx(tonumber(ix)), cz(tonumber(iz)))
		gTotal += 1
		if has(2 * M - p) then pointHit += 1 end
		if has(p - 2 * (p - M):Dot(u) * u) then mirrorHit += 1 end
	end
	local walkN = tierN.ground + tierN.mid + tierN.high
	local function pct(a, b) return math.floor(a / math.max(1, b) * 1000 + 0.5) / 10 end

	return HttpService:JSONEncode({
		map = MAPNAME,
		size = { math.floor(whi.X - wlo.X + CELL), math.floor(whi.Y - wlo.Y + CELL) },
		spawnDistance = math.floor((A - B).Magnitude),
		spawnLineEye = cast(eA, eB - eA) and "blocked" or "OPEN",
		tiersPct = { ground = pct(tierN.ground, walkN), mid = pct(tierN.mid, walkN), high = pct(tierN.high, walkN) },
		walkRoutes = #routes, routeLengths = routes,
		longPairsVisiblePct = pct(longVisible, longPairs), maxVisibleLine = math.floor(maxVisible),
		spawnSeesPct = { A = exposure(eA), B = exposure(eB) },
		centreCoverPct = { head = pct(head, cells), waist = pct(waist, cells), noFloor = pct(void, cells) },
		symmetryPct = { point = pct(pointHit, gTotal), mirror = pct(mirrorHit, gTotal) },
		nodes = #nodes, rays = rays,
	})
end
