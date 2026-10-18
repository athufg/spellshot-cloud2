--!strict
--[[
	TTPose  (ModuleScript)  -- the Twin Tide pose evaluator, table format "tt_pose v4.1" (2026-09-26). The same maths as
	tt_pose.py (Blender); both read the same table, tt_pose.json (tt_pose_table.luau is that JSON as a ModuleScript).
	Pure Luau: CFrame, Vector3 and math only -- no Instance, no service.
	v4: the per-column sine WOBBLE is removed (the owner: "The wiggle the waves have is not realistic, remove the
	wiggle"): no wobbleChains / wobbleEnv / columns[c].wobble in the table, no wobble term here.
	v4.1 (review round 2): the wall's colour stages no longer cycle (stages.keys = { {e, stage} }: one stage per phase;
	v4's stages.cycle / period / from / white / whiteFrom are gone), and the jet's flash is Neon in the Twin Tide flash
	colour #4FBDF6 (manifests/tt_jet.json flash_colour), not white. The Twin Tide lines (AK_TT_Lip, AK_TT_JetLine_n,
	AK_TT_SimLine_NN) are Neon in the Twin Tide line colour #2690E4 (manifests line_colour), not the kit's #3CE8E0.

	CALLS
	  TTPose.transform(tbl, chain: string, column: number, e: number, restRot: CFrame?) -> CFrame
	      The Bone.Transform for bone `chain` of column `column` (1..7) at `e` seconds after the cast (e past
	      tbl.endTime holds the last pose). chain is any chain in the table: the wall rig's "Foot" | "Face" | "Throat" |
	      "Crest" | "Lip" | "Claw" | "ClawTip" | "Back" | "Skirt", the cap rig's "CapA".."CapF", the collar rig's
	      "ColA" | "ColB" | "ColTop". It rotates about the bone's own head, then translates, in the bone's REST axes,
	      which the rigs make identical to their MeshPart's axes. If the importer ever gives the bones a rest rotation,
	      pass it once as restRot = the bone's rest rotation relative to its MeshPart (read before any Transform is
	      written: (part.CFrame:Inverse() * bone.WorldCFrame).Rotation) and the result is restRot:Inverse() * T * restRot.
	  TTPose.parse(boneName: string) -> (string?, number?)
	      "C3_Throat" -> "Throat", 3;  "C3_Crest_L" / "C3_Crest_2" (a suffixed bone set) -> "Crest", 3;  "C3_CapE" ->
	      "CapE", 3;  "Root" / "LipRoot" / "CapRoot" / "CollarRoot" -> nil.
	  TTPose.travel(e: number, closeTime: number?, start: number?, meet: number?, hold: number?, tau: number?)
	      -> (number, number)
	      The wall ORIGIN's distance from the seam and its speed toward it (AquaFX places each wall's origin at +-off
	      across the lane, facing the seam): nearly in place for `hold` (0.3) s, then a quadratic ease-in
	      off = start - (start - meet) * s^2, s = (e - hold) / (closeTime - hold), arriving at V = 18.625 studs/s at
	      closeTime; AFTER closeTime the walls keep closing, decaying: off = meet - V * tau * (1 - exp(-(e - closeTime) /
	      tau)). Defaults 1.1, 11, 3.55, 0.3, 0.09.
	  TTPose.jet(tbl, e: number) -> (number, boolean, number)
	      The flip-through JET (rigid stage meshes AK_TT_Jet_1..N and rim lines AK_TT_JetLine_1..N, fbx/tt_jet.fbx):
	      stage (1..N; 0 = none), flash (true on the one bright frame: draw that stage Neon #4FBDF6; latch it so it shows on
	      at least one frame), top (the jet's top above the floor). Show only AK_TT_Jet_<stage>, UNSCALED, at the seam:
	      its origin on the floor at the lane's centre, the part's X along the lane (symmetric: either way round).
	  TTPose.wallStage(tbl, e: number) -> number
	      Which colour stage AK_TT_Wall_<n> (1..4) shows: the stage of the last stages.keys entry whose e has passed
	      (1 to the stand at 0.40, 2 through the stand, 3 from the pitch at 0.70, the lighter stage 4 from 1.00; no
	      cycling). Hide the others (and only pose the one showing; write its bones before showing it).
	  TTPose.lines(tbl, e: number) -> (boolean, boolean)
	      (lipLit, jetLineLit): the lips' Tidelines (AK_TT_Lip) Neon (#2690E4) until lines.lipDarkAt, then "dark"; the jet's rim
	      line AK_TT_JetLine_<stage> Neon from lines.jetLineFrom while a jet stage shows.
	  TTPose.collarOn(tbl, e: number) -> boolean
	      AK_TT_Collar shows over [collar.show, collar.hide). It sits in the SEAM frame of the side +1 wall: CFrame =
	      that wall's part rotation, origin on the floor at the lane's centre.
	  TTPose.capOn(tbl, e: number) -> boolean
	      AK_TT_Cap shows from cap.show (0.69 s); before that it is collapsed onto the lip's edge anyway.
	  TTPose.dropCount(tbl) -> number
	      0 since v4 round 3 (2026-09-26, the owner: "Remove the claws first"): the walls have no claws, so the table's
	      drops.list is empty; loop i = 1, dropCount and nothing runs. Same format (tt_pose v4.1), same calls.
	  TTPose.drop(tbl, i: number, e: number) -> (boolean, CFrame?, Vector3?)
	      Drop i (1..dropCount) pinched off a claw: (on, cf, scale). cf is in the wall's SEAM frame (its part CFrame *
	      CFrame.new(0, 0, -off(e)): the seam point, the wall's rotation), the drop's head (-Z) aimed along its velocity;
	      scale multiplies AK_WG_Drop's size (stretched along its travel). Use the same list for both walls, each in its
	      own seam frame. These are capped pieces (take() from the pool; skip one when the pool is full).

	USE (per wall, per Heartbeat): for every bone of the showing wall stage, of AK_TT_Lip and of AK_TT_Cap:
	    b.Bone.Transform = TTPose.transform(TABLE, b.Chain, b.Column, e)
	and for the collar's bones the same with ITS chains. Parts keep Size = TemplateSize (never resize a skinned part).

	THE TABLE (v4.1): columns[c] = { x, lag, lift = { {u, y} },
	keys = { [chain] = { {u, t = {x,y,z}, r = {x,y,z}} } } }: per-column keys (u = e / closeTime), cubic Hermite per
	component (Catmull-Rom tangents, one-sided at the ends, clamped outside). The peel: while u < 1 a column runs on
	uc = u - lag * sin(pi * u^lagPower) (not the unwarpedChains). lift is added to Y for the liftChains.
]]

local TTPose = {}

local function clamp(x: number, a: number, b: number): number
	if x < a then return a end
	if x > b then return b end
	return x
end

local function smoothstep(a: number, b: number, x: number): number
	local t
	if b == a then
		t = if x >= b then 1 else 0
	else
		t = clamp((x - a) / (b - a), 0, 1)
	end
	return t * t * (3 - 2 * t)
end

-- cubic Hermite through keys[i].u / keys[i][field][c]; tangents (p[i+1] - p[i-1]) / (u[i+1] - u[i-1]), one-sided at
-- the ends; clamped outside the keys. `c` = component 1..3, or nil for a scalar field.
local function slope(keys: { any }, field: string, c: number?, j: number, n: number): number
	local function v(k: number): number
		local f = keys[k][field]
		return if c then f[c] else f
	end
	if j == 1 then
		return (v(2) - v(1)) / (keys[2].u - keys[1].u)
	elseif j == n then
		return (v(n) - v(n - 1)) / (keys[n].u - keys[n - 1].u)
	end
	return (v(j + 1) - v(j - 1)) / (keys[j + 1].u - keys[j - 1].u)
end

local function hermite(keys: { any }, field: string, c: number?, u: number): number
	local n = #keys
	local function v(k: number): number
		local f = keys[k][field]
		return if c then f[c] else f
	end
	if u <= keys[1].u then return v(1) end
	if u >= keys[n].u then return v(n) end
	local i = 1
	while i < n - 1 and u > keys[i + 1].u do
		i += 1
	end
	local u0, u1 = keys[i].u, keys[i + 1].u
	local h = u1 - u0
	local s = (u - u0) / h
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
	return h00 * v(i) + h10 * h * slope(keys, field, c, i, n) + h01 * v(i + 1) + h11 * h * slope(keys, field, c, i + 1, n)
end

local function contains(list: { any }, x: any): boolean
	for _, v in list do
		if v == x then return true end
	end
	return false
end

--- (u, uc): the normalised time and column `column`'s peeled time (warped = false: world time, for the collar).
function TTPose.columnTime(tbl: any, column: number, e: number, warped: boolean?): (number, number)
	local u = clamp(e / tbl.closeTime, 0, tbl.endTime / tbl.closeTime)
	if warped == false or u >= 1 then
		return u, u
	end
	local lag = tbl.columns[column].lag
	return u, u - lag * math.sin(math.pi * u ^ tbl.lagPower)
end

--- The Transform as (translation Vector3, rotation-vector Vector3), Roblox axes.
function TTPose.components(tbl: any, chain: string, column: number, e: number): (Vector3, Vector3)
	local col = tbl.columns[column]
	local _, uc = TTPose.columnTime(tbl, column, e, not contains(tbl.unwarpedChains, chain))
	local keys = col.keys[chain]
	local tx = hermite(keys, "t", 1, uc)
	local ty = hermite(keys, "t", 2, uc)
	local tz = hermite(keys, "t", 3, uc)
	local rx, ry, rz = hermite(keys, "r", 1, uc), hermite(keys, "r", 2, uc), hermite(keys, "r", 3, uc)
	if contains(tbl.liftChains, chain) then
		ty += hermite(col.lift, "y", nil, uc)
	end
	return Vector3.new(tx, ty, tz), Vector3.new(rx, ry, rz)
end

function TTPose.transform(tbl: any, chain: string, column: number, e: number, restRot: CFrame?): CFrame
	local t, r = TTPose.components(tbl, chain, column, e)
	local angle = r.Magnitude
	local cf = if angle > 1e-9 then CFrame.new(t) * CFrame.fromAxisAngle(r / angle, angle) else CFrame.new(t)
	if restRot then
		return restRot:Inverse() * cf * restRot
	end
	return cf
end

function TTPose.parse(boneName: string): (string?, number?)
	local col, chain = string.match(boneName, "^C(%d+)_(%a+)")
	if not col then return nil, nil end
	return chain, tonumber(col)
end

function TTPose.travel(e: number, closeTime: number?, start: number?, meet: number?, hold: number?, tau: number?): (number, number)
	local ct, s0, m, hd, ta = closeTime or 1.1, start or 11, meet or 3.55, hold or 0.3, tau or 0.09
	local span = ct - hd
	local vmax = 2 * (s0 - m) / span
	if e <= ct then
		local s = clamp((e - hd) / span, 0, 1)
		return s0 - (s0 - m) * s * s, if e > hd then vmax * s else 0
	end
	local k = math.exp(-(e - ct) / ta)
	return m - vmax * ta * (1 - k), vmax * k
end

function TTPose.jet(tbl: any, e: number): (number, boolean, number)
	local J = tbl.jet
	if e < J.spawn or e >= J.stop then
		return 0, false, 0
	end
	local d = e - J.spawn
	local top = J.zTop0 + J.v0 * d - 0.5 * J.g * d * d
	local stage = 1
	for i, s in J.stages do
		if e >= s.e then
			stage = i
		end
	end
	local fl = J.flash
	return stage, (e >= fl.e and e < fl.e + fl.dur), top
end

function TTPose.wallStage(tbl: any, e: number): number
	local K = tbl.stages.keys
	local stage = K[1][2]
	for _, k in K do
		if e >= k[1] then
			stage = k[2]
		end
	end
	return stage
end

function TTPose.lines(tbl: any, e: number): (boolean, boolean)
	local L = tbl.lines
	local stage = TTPose.jet(tbl, e)
	return e < L.lipDarkAt, (stage > 0 and e >= L.jetLineFrom)
end

function TTPose.collarOn(tbl: any, e: number): boolean
	return e >= tbl.collar.show and e < tbl.collar.hide
end

function TTPose.capOn(tbl: any, e: number): boolean
	return e >= tbl.cap.show
end

function TTPose.dropCount(tbl: any): number
	return #tbl.drops.list
end

function TTPose.drop(tbl: any, i: number, e: number): (boolean, CFrame?, Vector3?)
	local D = tbl.drops
	local d = D.list[i]
	local tau = e - d.e
	local life = D.life
	if tau < 0 or tau >= life then
		return false, nil, nil
	end
	local g = D.g
	local px = d.p[1] + d.v[1] * tau
	local py = d.p[2] + d.v[2] * tau - 0.5 * g * tau * tau
	local pz = d.p[3] + d.v[3] * tau
	if py < 0.05 then
		return false, nil, nil
	end
	local vx, vy, vz = d.v[1], d.v[2] - g * tau, d.v[3]
	local sp = math.sqrt(vx * vx + vy * vy + vz * vz)
	local lx, ly, lz = 0, -1, 0
	if sp > 1e-6 then
		lx, ly, lz = vx / sp, vy / sp, vz / sp
	end
	-- right = look x up (up = +Y; +Z when the drop flies straight up or down), up' = right x look
	local ux, uy, uz = 0, 1, 0
	local rx, ry, rz = ly * uz - lz * uy, lz * ux - lx * uz, lx * uy - ly * ux
	local m = math.sqrt(rx * rx + ry * ry + rz * rz)
	if m < 1e-4 then
		ux, uy, uz = 0, 0, 1
		rx, ry, rz = ly * uz - lz * uy, lz * ux - lx * uz, lx * uy - ly * ux
		m = math.sqrt(rx * rx + ry * ry + rz * rz)
	end
	rx, ry, rz = rx / m, ry / m, rz / m
	local qx, qy, qz = ry * lz - rz * ly, rz * lx - rx * lz, rx * ly - ry * lx
	local cf = CFrame.new(px, py, pz, rx, qx, -lx, ry, qy, -ly, rz, qz, -lz)
	local k = math.max(0.05, 1 - smoothstep(0.6, 1.0, tau / life))
	local s = d.s * k
	local stretch = math.min(D.stretchMax, 1 + D.stretchPerSpeed * sp)
	return true, cf, Vector3.new(s, s, s * stretch)
end

return TTPose
