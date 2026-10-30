"""python run_queue.py <queue.txt> [N]: each line '<tag> <mode>' runs launch.py pkg_<tag>.json (teamwork on) unless
results_<mode>_<tag>.json already exists, so a stopped queue resumes where it left off. Re-reads the file each step."""
import os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
q, N = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "6"
while True:
    todo = [l.split() for l in open(os.path.join(HERE, q)) if l.strip() and not l.startswith("#")]
    todo = [(x[0], x[1], x[2] if len(x) > 2 else N) for x in todo]           # optional third column: rounds per pairing
    todo = [(t, m, n) for t, m, n in todo if not os.path.exists(os.path.join(HERE, f"results_{m}_{t}.json"))]
    if not todo: break
    tag, mode, n_ = todo[0]
    t0 = time.time(); print(f"[{time.strftime('%H:%M:%S')}] start {tag} ({len(todo)} left)", flush=True)
    rc = subprocess.call([sys.executable, "launch.py", f"pkg_{tag}.json", "1", mode, n_, tag], cwd=HERE,
                         stdout=subprocess.DEVNULL)
    print(f"[{time.strftime('%H:%M:%S')}] done {tag} rc={rc} {time.time() - t0:.0f}s", flush=True)
    if rc != 0: break
print("queue empty")
