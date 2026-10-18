"""Export every script in the open Cool VFX place into D:/Spellshot/SPELLSHOT/roblox, byte-verified.

Talks to Roblox's StudioMCP.exe directly over stdio (same protocol an MCP host uses), so the ~300 KB of
source never has to pass through a chat transcript. Each script's Source is returned JSON-encoded along
with a byte count and rolling hash computed INSIDE Studio; a file is only written if the decoded bytes
reproduce that hash exactly.

File naming follows the repo: Script -> Name.server.lua, LocalScript -> Name.client.lua,
ModuleScript -> Name.lua. MatchHUD_RETIRED lives in the repo as MatchHUD.client.lua.
Line endings: a file that already exists keeps its style (CRLF files stay CRLF), so git shows only
real changes. New files are LF, like the files most recently added to the repo.

Usage: export_studio_scripts.py [--dry-run] [--server] [--no-temp]   (--server: read the Play server; --no-temp: skip _-prefixed test harnesses)
"""
import json, os, queue, subprocess, sys, threading, time

PLACE_ID = "126362651110745"
# the repo's own roblox/ folder, wherever the repo is checked out (it was a fixed D:\Spellshot\... path, which is not
# where the repo lives on every machine -- 2026-09-25)
DEST = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roblox"))
MCP_BAT = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "mcp.bat")
DRY = "--dry-run" in sys.argv
DM = "Server" if "--server" in sys.argv else "Edit"
RENAME = {"MatchHUD_RETIRED": "MatchHUD"}
SUFFIX = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}
MOD = 1000000007


def rhash(bs):
    h = 0
    for b in bs:
        h = (h * 31 + b) % MOD
    return h


class Client:
    def __init__(self):
        self.p = subprocess.Popen(["cmd.exe", "/c", MCP_BAT], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, cwd=os.path.dirname(MCP_BAT),
                                  text=True, encoding="utf-8", bufsize=1)
        self.q = queue.Queue()
        threading.Thread(target=self._pump, daemon=True).start()
        self.nid = 1

    def _pump(self):
        for line in self.p.stdout:
            line = line.strip()
            if line:
                self.q.put(line)

    def send(self, o):
        self.p.stdin.write(json.dumps(o) + "\n")
        self.p.stdin.flush()

    def req(self, method, params=None, timeout=60):
        rid = self.nid
        self.nid += 1
        m = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            m["params"] = params
        self.send(m)
        end = time.time() + timeout
        while time.time() < end:
            try:
                line = self.q.get(timeout=0.25)
            except queue.Empty:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("id") == rid:
                if "error" in o:
                    raise RuntimeError(o["error"])
                return o["result"]
        raise TimeoutError(method)

    def tool(self, name, args, timeout=120):
        r = self.req("tools/call", {"name": name, "arguments": args}, timeout)
        txt = "\n".join(i.get("text", "") for i in r.get("content", []) if i.get("type") == "text")
        return r.get("isError", False), txt

    def close(self):
        try:
            self.p.stdin.close()
            self.p.wait(timeout=3)
        except Exception:
            self.p.kill()


LIST_LUAU = r'''
local HttpService = game:GetService("HttpService")
local NO_TEMP = __NO_TEMP__
local roots = { game:GetService("ServerScriptService"), game:GetService("StarterPlayer"), game:GetService("StarterGui"),
	game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst"), workspace }
local list = {}
for _, r in ipairs(roots) do
	for _, d in ipairs(r:GetDescendants()) do
		local char = d:FindFirstAncestorWhichIsA("Model")
		local isCharacter = char and game:GetService("Players"):GetPlayerFromCharacter(char) ~= nil
		-- (--server, during Play: Roblox's own default player scripts appear in StarterPlayer; they are not the game's)
		local rbx = d:FindFirstAncestor("PlayerModule") or d.Name == "PlayerModule" or d.Name == "RbxCharacterSounds"
			or d:FindFirstAncestor("RbxCharacterSounds")
		-- (--no-temp: a session's temporary test harness, named with a leading underscore)
		local temp = NO_TEMP and string.sub(d.Name, 1, 1) == "_"
		if d:IsA("LuaSourceContainer") and not isCharacter and not rbx and not temp then
			table.insert(list, { name = d.Name, class = d.ClassName, path = d:GetFullName() })
		end
	end
end
return HttpService:JSONEncode(list)
'''

GET_LUAU = r'''
local HttpService = game:GetService("HttpService")
local target
for _, d in ipairs(game:GetDescendants()) do
	if d:IsA("LuaSourceContainer") and d:GetFullName() == %s then target = d break end
end
if not target then return HttpService:JSONEncode({ missing = true }) end
local src = target.Source
local first, count = %d, %d
if first == 1 then
	local h = 0
	for i = 1, #src do h = (h * 31 + string.byte(src, i)) %% 1000000007 end
	return HttpService:JSONEncode({ source = string.sub(src, 1, count), bytes = #src, hash = h })
end
return HttpService:JSONEncode({ source = string.sub(src, first, first + count - 1) })
'''
CHUNK = 30000     # bytes per round trip: a whole large module overflows one tool response


def main():
    c = Client()
    try:
        c.req("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                             "clientInfo": {"name": "spellshot-export", "version": "1"}})
        c.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        sid = None
        end = time.time() + 60
        while time.time() < end and not sid:
            err, txt = c.tool("list_roblox_studios", {}, 20)
            if not err:
                for s in json.loads(txt).get("studios", []):
                    if PLACE_ID in (s.get("name") or ""):
                        sid = s["id"]
            if not sid:
                time.sleep(2)
        if not sid:
            raise SystemExit("Cool VFX studio instance did not attach")

        err, txt = c.tool("execute_luau", {"code": LIST_LUAU.replace("__NO_TEMP__", "true" if "--no-temp" in sys.argv else "false"), "datamodel_type": DM, "studio_id": sid})
        if err:
            raise SystemExit("list failed: " + txt)
        scripts = json.loads(txt)
        report = []
        for s in scripts:
            base = RENAME.get(s["name"], s["name"]) + SUFFIX[s["class"]]
            dest = os.path.join(DEST, base)
            err, txt = c.tool("execute_luau", {"code": GET_LUAU % (json.dumps(s["path"]), 1, CHUNK),
                                               "datamodel_type": DM, "studio_id": sid})
            if err:
                report.append(("ERROR", base, txt[:200]))
                continue
            data = json.loads(txt)
            if data.get("missing"):
                report.append(("MISSING", base, s["path"]))
                continue
            parts = [data["source"].encode("utf-8")]
            got = len(parts[0])
            while got < data["bytes"]:
                err, txt = c.tool("execute_luau", {"code": GET_LUAU % (json.dumps(s["path"]), got + 1, CHUNK),
                                                   "datamodel_type": DM, "studio_id": sid})
                piece = json.loads(txt)["source"].encode("utf-8") if not err else b""
                if not piece:
                    break
                parts.append(piece)
                got += len(piece)
            studio_bytes = b"".join(parts)
            if len(studio_bytes) != data["bytes"] or rhash(studio_bytes) != data["hash"]:
                report.append(("HASH-MISMATCH", base, f"{len(studio_bytes)} vs {data['bytes']}"))
                continue

            if os.path.exists(dest):
                with open(dest, "rb") as f:
                    local = f.read()
                crlf = b"\r\n" in local
                if local.replace(b"\r\n", b"\n") == studio_bytes:
                    report.append(("same", base, ""))
                    continue
                out = studio_bytes.replace(b"\n", b"\r\n") if crlf else studio_bytes
                status = "UPDATED" + (" (crlf kept)" if crlf else "")
            else:
                out = studio_bytes
                status = "NEW"
            if not DRY:
                with open(dest, "wb") as f:
                    f.write(out)
            report.append((status, base, f"{s['class']} {s['path']} {len(studio_bytes)} bytes"))

        for r in sorted(report, key=lambda r: (r[0] == "same", r[0], r[1])):
            print(f"{r[0]:<22} {r[1]:<36} {r[2]}")
        print("DRY RUN - nothing written" if DRY else "written")
    finally:
        c.close()


if __name__ == "__main__":
    main()
