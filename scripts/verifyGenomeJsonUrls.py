#!/usr/bin/env python3
# Verifies every URL referenced from the genome definitions in genomes/json and
# genomes/legacy/json, and writes a markdown report of the ones that fail.
#
# Usage: python3 scripts/verifyGenomeJsonUrls.py [report.md]   (default: scratch/url_report.md)

import json, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict

root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
report = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "scratch/url_report.md")
dirs = ["genomes/json", "genomes/legacy/json"]
refs = defaultdict(list)   # url -> [(file, key)]
bad_json = []

def walk(o, f, key=None):
    if isinstance(o, dict):
        for k, v in o.items(): walk(v, f, k)
    elif isinstance(o, list):
        for v in o: walk(v, f, key)
    elif isinstance(o, str) and o.startswith(("http://", "https://", "ftp://")):
        refs[o].append((f, key))

for d in dirs:
    for name in sorted(os.listdir(os.path.join(root, d))):
        if not name.endswith(".json"): continue
        rel = f"{d}/{name}"
        try:
            walk(json.load(open(os.path.join(root, rel))), rel)
        except Exception as e:
            bad_json.append((rel, str(e)))

def req(url, method):
    args = ["curl", "-s", "-L", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "60", "-r", "0-0"]
    if method == "HEAD": args.append("--head")
    p = subprocess.run(args + [url], capture_output=True, text=True)
    code = int(p.stdout or 0)
    if url.startswith("ftp://"):
        return (200, "") if p.returncode == 0 else (None, f"curl exit {p.returncode}")
    if code == 0: return None, "malformed URL (contains spaces)" if p.returncode == 3 else f"curl exit {p.returncode} (no response)"
    return code, ""

def check(url):
    if url.startswith("ftp://"):
        s, msg = req(url, "GET"); return url, s, msg
    s, msg = req(url, "HEAD")
    if s is None or s >= 400:
        s2, msg2 = req(url, "GET")   # some servers reject HEAD
        if s2 is not None and s2 < 400: return url, s2, "(HEAD failed; GET ok)"
        if s2 is not None: s, msg = s2, msg2
    return url, s, msg

with ThreadPoolExecutor(16) as ex:
    results = list(ex.map(check, sorted(refs)))

failures = [(u, s, m) for u, s, m in results if s is None or s >= 400]
out = ["# Genome definition URL check", "",
       f"Checked {len(refs)} unique URLs referenced from `genomes/json` and `genomes/legacy/json`.", "",
       f"**{len(failures)} failing URLs.**", ""]
if bad_json:
    out += ["## Unparseable JSON files", ""] + [f"- `{f}`: {e}" for f, e in bad_json] + [""]
by_status = defaultdict(list)
for u, s, m in failures: by_status[s if s else "Invalid URL"].append((u, m))
for s in sorted(by_status, key=str):
    out += [f"## {s}", "", "| URL | Referenced from | Detail |", "|---|---|---|"]
    for u, m in by_status[s]:
        where = "<br>".join(sorted({f"`{f}` ({k})" for f, k in refs[u]}))
        out.append(f"| {u} | {where} | {m.replace('|', '/')} |")
    out.append("")
open(report, "w").write("\n".join(out))
print(len(refs), "urls,", len(failures), "failures")
for u, s, m in failures: print(s, u, m)
