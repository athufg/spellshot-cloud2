"""Export the whole SPELLSHOT game tree from the open Studio place into <repo>/game, mirroring the Explorer.

For a cloud session that can read text but never open Studio. Two outputs:
  game/<Service>/<...>/<Name>.lua           every Script (.server.lua), LocalScript (.client.lua) and ModuleScript (.lua),
                                            at its Explorer path; a script's own children live in a folder of its name
                                            next to it (Fireball.lua + Fireball/...)
  game/manifest.json                        the non-script tree: every instance's class, attributes and key properties
                                            (values, asset ids, remotes, sizes); big part piles are summarised as counts
Sources come straight from Studio over StudioMCP's stdio (same client as export_studio_scripts.py), byte-verified
against a hash computed inside Studio, so ~6 MB of code never passes through a chat transcript.

Skipped on purpose (listed in the manifest's "skipped" section): engine services (CoreGui, CorePackages, Players...),
Roblox's runtime player scripts, and the old-version backup folders in ServerStorage (*Superseded*, *Backup*).
File names: characters Windows forbids become "_", and same-named siblings get " (2)", " (3)"...; the manifest's
"renamed" list maps every such file back to its real Explorer path.

Usage: export_game_tree.py <repo_dir> [--dry-run]       (Studio open on the SPELLSHOT place, Edit mode preferred)
"""
import json, os, re, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_studio_scripts import Client, rhash, PLACE_ID  # noqa: E402

CHUNK = 30000
SUFFIX = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}

# --- Studio side ---------------------------------------------------------------------------------------------------
PRELUDE = r'''
local HttpService = game:GetService("HttpService")
local SKIP_SERVICES = { CoreGui = true, CorePackages = true, Players = true, RobloxPluginGuiService = true,
	PluginGuiService = true, PluginDebugService = true, TestService = false, Visit = true }
local function skippedBranch(d)
	-- old-version backups kept in ServerStorage, and Roblox's own runtime player scripts
	local x = d
	while x and x ~= game do
		local p = x.Parent
		if p == game:GetService("ServerStorage") and (x.Name:find("Superseded") or x.Name:find("Backup") or x.Name:find("backup")) then return x end
		if x.Name == "PlayerModule" or x.Name == "RbxCharacterSounds" then return x end
		x = p
	end
	return nil
end
local function services()
	local out = {}
	for _, s in ipairs(game:GetChildren()) do
		local ok, name = pcall(function() return s.Name end)
		if ok and not SKIP_SERVICES[s.ClassName] and not SKIP_SERVICES[name] then out[#out + 1] = s end
	end
	return out
end
local function segs(d)
	local t = {}
	local x = d
	while x and x ~= game do table.insert(t, 1, x.Name) x = x.Parent end
	return t
end
'''

LIST = PRELUDE + r'''
local list, skipped, seen = {}, {}, {}
_G.__exp = {}
for _, s in ipairs(services()) do
	local okD, desc = pcall(function() return s:GetDescendants() end)
	for _, d in ipairs(okD and desc or {}) do
		if d:IsA("LuaSourceContainer") and SUFFIX_OK[d.ClassName] then
			local sk = skippedBranch(d)
			if sk then
				if not seen[sk] then seen[sk] = true skipped[#skipped + 1] = sk:GetFullName() end
			else
				_G.__exp[#_G.__exp + 1] = d
				local kids = 0
				for _, c in ipairs(d:GetChildren()) do kids += 1 end
				list[#list + 1] = { i = #_G.__exp, class = d.ClassName, segs = segs(d), kids = kids }
			end
		end
	end
end
return HttpService:JSONEncode({ list = list, skipped = skipped })
'''.replace("SUFFIX_OK[d.ClassName]", '({ Script = true, LocalScript = true, ModuleScript = true })[d.ClassName]')

GET = r'''
local HttpService = game:GetService("HttpService")
local d = _G.__exp and _G.__exp[%d]
if not d then return HttpService:JSONEncode({ missing = true }) end
local src = d.Source
local first, count = %d, %d
if first == 1 then
	local h = 0
	for i = 1, #src do h = (h * 31 + string.byte(src, i)) %% 1000000007 end
	return HttpService:JSONEncode({ source = string.sub(src, 1, count), bytes = #src, hash = h })
end
return HttpService:JSONEncode({ source = string.sub(src, first, first + count - 1) })
'''

MANIFEST = PRELUDE + r'''
-- the non-script tree, summarised where parts pile up
local function hex(c) return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function val(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then return v end
	if t == "Color3" then return hex(v) end
	if t == "Vector3" then return string.format("%.3g, %.3g, %.3g", v.X, v.Y, v.Z) end
	if t == "Vector2" then return string.format("%.3g, %.3g", v.X, v.Y) end
	if t == "UDim2" then return tostring(v) end
	if t == "Instance" then return v:GetFullName() end
	if t == "EnumItem" then return tostring(v) end
	return t .. ":" .. tostring(v)
end
local PROPS = {
	ValueBase = { "Value" }, Sound = { "SoundId", "Volume" }, Animation = { "AnimationId" }, Decal = { "Texture" },
	Texture = { "Texture" }, MeshPart = { "MeshId", "TextureID" }, SpecialMesh = { "MeshId", "TextureId", "MeshType" },
	ParticleEmitter = { "Texture", "Rate", "Enabled" }, Beam = { "Texture" }, Trail = { "Texture" },
	ImageLabel = { "Image" }, ImageButton = { "Image" }, TextLabel = { "Text" }, TextButton = { "Text" },
	BasePart = { "Size", "Material", "Color", "Transparency", "Anchored", "CanCollide" },
	Model = {}, Light = { "Brightness", "Range", "Color" },
	Atmosphere = { "Density", "Color", "Decay" }, Sky = { "SkyboxBk" }, ColorCorrectionEffect = { "TintColor", "Saturation", "Contrast", "Brightness" },
	BloomEffect = { "Intensity", "Size", "Threshold" }, Humanoid = { "MaxHealth", "WalkSpeed" },
}
local PART_PILE = 40
local budget = 60000
local function node(d, depth)
	budget -= 1
	local n = { n = d.Name, c = d.ClassName }
	local ok, attrs = pcall(function() return d:GetAttributes() end)
	if ok and next(attrs) then
		n.a = {}
		for k, v in pairs(attrs) do n.a[k] = val(v) end
	end
	for cls, list in pairs(PROPS) do
		if d:IsA(cls) then
			n.p = n.p or {}
			for _, prop in ipairs(list) do
				local ok2, v = pcall(function() return d[prop] end)
				if ok2 and v ~= nil and v ~= "" then n.p[prop] = val(v) end
			end
		end
	end
	if d:IsA("Model") then
		local ok3, ext = pcall(function() return d:GetExtentsSize() end)
		if ok3 then n.p = n.p or {} n.p.ExtentsSize = val(ext) end
	end
	if d:IsA("LuaSourceContainer") then n.script = true end
	local kids = d:GetChildren()
	if #kids == 0 then return n end
	local parts = 0
	for _, c in ipairs(kids) do if c:IsA("BasePart") then parts += 1 end end
	if (parts > PART_PILE or budget <= 0 or depth > 12) then
		local counts, deep = {}, 0
		for _, c in ipairs(d:GetDescendants()) do counts[c.ClassName] = (counts[c.ClassName] or 0) + 1 deep += 1 end
		n.summary = { descendants = deep, byClass = counts }
		-- still name the non-part children (scripts, folders, values, models) one level down
		n.k = {}
		for _, c in ipairs(kids) do
			if not c:IsA("BasePart") and budget > 0 then n.k[#n.k + 1] = { n = c.Name, c = c.ClassName } end
		end
		return n
	end
	n.k = {}
	for _, c in ipairs(kids) do
		if not skippedBranch(c) then n.k[#n.k + 1] = node(c, depth + 1) end
	end
	return n
end
local root = { place = game.PlaceId, services = {} }
for _, s in ipairs(services()) do
	local ok, n = pcall(node, s, 0)
	if ok then root.services[#root.services + 1] = n end
end
_G.__manifest = HttpService:JSONEncode(root)
return tostring(#_G.__manifest)
'''

MANIFEST_GET = r'''return string.sub(_G.__manifest or "", %d, %d)'''

BAD = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def clean(name):
    c = BAD.sub("_", name).rstrip(" .") or "_"
    if c.upper() in {"CON", "PRN", "AUX", "NUL"} or re.fullmatch(r"(?i)(COM|LPT)\d", c):
        c = "_" + c
    return c


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    repo = os.path.abspath(sys.argv[1])
    dry = "--dry-run" in sys.argv
    out_dir = os.path.join(repo, "game")
    c = Client()
    try:
        c.req("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                             "clientInfo": {"name": "spellshot-tree-export", "version": "1"}})
        c.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        sid, end = None, time.time() + 60
        while time.time() < end and not sid:
            err, txt = c.tool("list_roblox_studios", {}, 20)
            if not err:
                for s in json.loads(txt).get("studios", []):
                    if PLACE_ID in (s.get("name") or ""):
                        sid = s["id"]
            if not sid:
                time.sleep(2)
        if not sid:
            raise SystemExit("Studio is not open on the SPELLSHOT place (or StudioMCP is off): open it and re-run")
        err, txt = c.tool("get_studio_state", {"studio_id": sid}, 20)
        dm = "Edit" if (not err and "Current Studio Mode: Edit" in txt) else "Server"
        if dm != "Edit":
            print("note: Studio is in Play; reading the server side (runtime-only player scripts are skipped)")

        err, txt = c.tool("execute_luau", {"code": LIST, "datamodel_type": dm, "studio_id": sid}, 300)
        if err:
            raise SystemExit("list failed: " + txt[:300])
        data = json.loads(txt)
        scripts, skipped = data["list"], data["skipped"]

        # file paths: mirror the Explorer; same-named siblings numbered; forbidden characters replaced
        used, renamed, files = {}, [], []
        for s in scripts:
            segs = s["segs"]
            dirs = [clean(x) for x in segs[:-1]]
            base = clean(segs[-1])
            rel_dir = os.path.join(*dirs) if dirs else ""
            stem, k = base, 1
            key = (rel_dir.lower(), stem.lower(), s["class"])
            while key in used:
                k += 1
                stem = f"{base} ({k})"
                key = (rel_dir.lower(), stem.lower(), s["class"])
            used[key] = True
            rel = os.path.join(rel_dir, stem + SUFFIX[s["class"]])
            if stem != segs[-1] or dirs != segs[:-1]:
                renamed.append({"file": rel.replace("\\", "/"), "explorer": ".".join(segs)})
            files.append((s, rel))

        report, total = {"written": 0, "same": 0, "errors": []}, 0
        for s, rel in files:
            err, txt = c.tool("execute_luau", {"code": GET % (s["i"], 1, CHUNK), "datamodel_type": dm, "studio_id": sid})
            if err:
                report["errors"].append((rel, txt[:160]))
                continue
            d = json.loads(txt)
            if d.get("missing"):
                report["errors"].append((rel, "missing"))
                continue
            parts = [d["source"].encode("utf-8")]
            got = len(parts[0])
            while got < d["bytes"]:
                err, txt = c.tool("execute_luau", {"code": GET % (s["i"], got + 1, CHUNK), "datamodel_type": dm, "studio_id": sid})
                piece = json.loads(txt)["source"].encode("utf-8") if not err else b""
                if not piece:
                    break
                parts.append(piece)
                got += len(piece)
            body = b"".join(parts)
            if len(body) != d["bytes"] or rhash(body) != d["hash"]:
                report["errors"].append((rel, f"hash mismatch {len(body)} vs {d['bytes']}"))
                continue
            total += len(body)
            dest = os.path.join(out_dir, rel)
            if os.path.exists(dest) and open(dest, "rb").read() == body:
                report["same"] += 1
                continue
            if not dry:
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                with open(dest, "wb") as f:
                    f.write(body)
            report["written"] += 1

        # scripts that no longer exist in Studio: their stale files go (only .lua files this tool wrote)
        keep = {os.path.normcase(os.path.join(out_dir, rel)) for _, rel in files}
        stale = []
        for dp, _, fns in os.walk(out_dir):
            for fn in fns:
                p = os.path.join(dp, fn)
                if fn.endswith(".lua") and os.path.normcase(p) not in keep:
                    stale.append(os.path.relpath(p, out_dir))
                    if not dry:
                        os.remove(p)

        # the manifest
        err, txt = c.tool("execute_luau", {"code": MANIFEST, "datamodel_type": dm, "studio_id": sid}, 600)
        if err:
            raise SystemExit("manifest failed: " + txt[:300])
        size, pieces, pos = int(txt.strip()), [], 1
        while pos <= size:
            err, txt = c.tool("execute_luau", {"code": MANIFEST_GET % (pos, pos + CHUNK - 1), "datamodel_type": dm, "studio_id": sid})
            if err:
                raise SystemExit("manifest read failed: " + txt[:200])
            pieces.append(txt)
            pos += CHUNK
        tree = json.loads("".join(pieces))
        # engine services with nothing of the game's in them are noise for a reader: keep only those with content
        GAME = {"Workspace", "Lighting", "MaterialService", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService",
                "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService", "Chat", "TextChatService",
                "LocalizationService"}
        tree["services"] = [s for s in tree["services"] if s["c"] in GAME and (s.get("k") or s.get("a") or s.get("summary"))]
        manifest = {
            "about": "The SPELLSHOT place's Explorer tree minus script sources (those are the .lua files beside this). "
                     "Per node: n = name, c = class, a = attributes, p = key properties, k = children, script = true "
                     "for a script (its source is a file), summary = a big pile of parts counted by class instead of listed.",
            "exported_from": "Roblox Studio, place " + PLACE_ID + (" (Play server side)" if dm != "Edit" else " (Edit)"),
            "scripts": len(files),
            "renamed": renamed,
            "skipped": {"note": "not exported: old-version backups in ServerStorage and Roblox runtime player scripts",
                        "branches": skipped},
            "tree": tree,
        }
        if not dry:
            os.makedirs(out_dir, exist_ok=True)
            with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=1, ensure_ascii=False)
        print(f"scripts {len(files)} ({total / 1e6:.2f} MB): written {report['written']}, unchanged {report['same']}, "
              f"stale removed {len(stale)}, renamed paths {len(renamed)}, skipped branches {len(skipped)}, "
              f"manifest {size / 1e6:.2f} MB" + (" (DRY RUN)" if dry else ""))
        for e in report["errors"]:
            print("ERROR", *e)
        for s in stale[:20]:
            print("stale", s)
    finally:
        c.close()


if __name__ == "__main__":
    main()
