"""python launch.py <package.json> <teamplay 0|1> <mode> <N> <tag> [variant]  -> runs run_all.py with that package's env"""
import json, os, subprocess, sys
env = dict(os.environ, **json.load(open(sys.argv[1])))
env["SIM_TEAMPLAY"] = sys.argv[2]; env["SIM_TAG"] = sys.argv[5]
if len(sys.argv) > 6: env["SIM_VAR"] = sys.argv[6]
sys.exit(subprocess.call([sys.executable, "run_all.py", sys.argv[3], sys.argv[4]], env=env, cwd=os.path.dirname(os.path.abspath(__file__))))
