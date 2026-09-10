#!/usr/bin/env python3
"""Verifies a mirror built by buildMirror.sh.

Usage: verifyMirror.py <mirror directory> [<host>]

  <mirror directory>  the output directory given to buildMirror.sh, the one
                      containing "genomes"
  <host>              the host it was built for, default https://igv.org

For genomes2.tsv, genomes3.tsv and web/genomes.json, checks that every genome
definition they reference is reachable, and then that the hubs those definitions
reference are reachable as well.  web/genomes.json holds its definitions inline
rather than by reference, so for that list only the hubs are followed.

A URL under <host>/genomes must resolve to a file in the mirror; json files are
parsed to catch a truncated copy.  URLs under <host>/genomes/data are the
exception, as that tree is hosted separately, and are checked over http along
with everything pointing off the mirror.

Exits non-zero if any reference does not resolve.
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

DEFAULT_HOST = "https://igv.org"

if not 2 <= len(sys.argv) <= 3:
    sys.exit(__doc__.split("\n\n")[1].strip())

MIRROR = sys.argv[1]
HOST = (sys.argv[2] if len(sys.argv) > 2 else DEFAULT_HOST).rstrip("/")
GENOMES = os.path.join(MIRROR, "genomes")
PREFIX = HOST + "/genomes/"
DATA_PREFIX = HOST + "/genomes/data/"

if not os.path.isdir(GENOMES):
    sys.exit("ERROR: no genomes directory in %s" % MIRROR)

http_cache = {}


def http_status(url):
    """Status of a one byte ranged GET, falling back to a plain GET."""
    if url not in http_cache:
        code = curl(url, ranged=True)
        if code in ("000", "400", "405", "501"):
            code = curl(url, ranged=False)
        http_cache[url] = code
    return http_cache[url]


def curl(url, ranged):
    args = ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-L", "--max-time", "30"]
    if ranged:
        args += ["-r", "0-0"]
    return subprocess.run(args + [url], capture_output=True, text=True).stdout.strip()


def local_path(url):
    """The file a mirror URL must resolve to, or None if it is not one."""
    if url.startswith(PREFIX) and not url.startswith(DATA_PREFIX):
        return os.path.join(GENOMES, url[len(PREFIX):])
    return None


def check(url):
    """Returns (ok, "mirror" or "http", detail)."""
    path = local_path(url)
    if path is None:
        code = http_status(url)
        return code in ("200", "206"), "http", code
    if not os.path.isfile(path):
        return False, "mirror", "missing from mirror"
    if os.path.getsize(path) == 0:
        return False, "mirror", "empty file"
    if path.endswith(".json"):
        try:
            with open(path) as f:
                json.load(f)
        except Exception as e:
            return False, "mirror", "invalid json: %s" % e
    return True, "mirror", os.path.relpath(path, MIRROR)


def read_tsv(name, column):
    """The URLs in the given column of a genome list."""
    urls = []
    with open(os.path.join(GENOMES, name)) as f:
        for line in f:
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) > column and fields[column].startswith("http"):
                urls.append(fields[column])
    return urls


def genome_configs(urls):
    """The genome definitions behind the mirror URLs that resolved."""
    configs = []
    for url in urls:
        path = local_path(url)
        if path and os.path.isfile(path):
            try:
                with open(path) as f:
                    configs.append(json.load(f))
            except Exception:
                pass                    # reported by check()
    return configs


def run(urls):
    with ThreadPoolExecutor(max_workers=12) as pool:
        return list(zip(urls, pool.map(check, urls)))


def report(title, results):
    counts = {}
    for _, (_, how, _) in results:
        counts[how] = counts.get(how, 0) + 1
    breakdown = ", ".join("%d %s" % (n, how) for how, n in sorted(counts.items()))
    failed = [(url, detail) for url, (ok, _, detail) in results if not ok]
    print("%s %s: %d checked (%s), %d failed"
          % ("FAIL" if failed else "OK  ", title, len(results), breakdown, len(failed)))
    for url, detail in failed:
        print("       %s  %s" % (detail, url))
    return len(failed)


def unique(items):
    seen, out = set(), []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


failures = 0
configs = []

for name, column in (("genomes3.tsv", 0), ("genomes2.tsv", 1)):
    urls = read_tsv(name, column)
    failures += report("%s genome definitions" % name, run(urls))
    configs += genome_configs(urls)

web = os.path.join(GENOMES, "web", "genomes.json")
try:
    with open(web) as f:
        inline = json.load(f)
    print("OK   web/genomes.json: parsed, %d genome definitions inline" % len(inline))
    configs += inline
except Exception as e:
    print("FAIL web/genomes.json: %s" % e)
    failures += 1

hubs = unique(hub for config in configs for hub in config.get("hubs", []))
failures += report("hubs referenced by those definitions", run(hubs))

print()
print("FAILURES: %d" % failures if failures else "All referenced files reachable")
sys.exit(1 if failures else 0)
