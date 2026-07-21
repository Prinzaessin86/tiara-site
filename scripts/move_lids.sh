#!/usr/bin/env bash
# Move migrated Linear ids from labels into issue TITLES, across the migrated repos.
# Idempotent + safe: only touches labels matching ^[A-Za-z]+-[0-9]+$, never alters original
# title text, skips issues already prefixed. Run as many times as you like.
#   bash scripts/move_lids.sh
set -uo pipefail

python3 - <<'PY'
import json, re, subprocess

repos = "SparkleReef Tiara-site PagingDrDaddy rainybow BloopPoop PodaProject Bubbles Dressie PackMagic".split()
lid_re = re.compile(r'^[A-Za-z]+-[0-9]+$')

grand = {}
for repo in repos:
    scanned = edited = removed = skipped = failures = 0
    fail_nums = []
    try:
        out = subprocess.run(
            ["gh","issue","list","-R",f"Prinzaessin86/{repo}","--state","all",
             "--limit","400","--json","number,title,labels"],
            capture_output=True, text=True, check=True).stdout
        issues = json.loads(out)
    except subprocess.CalledProcessError as e:
        print(f"[{repo}] LIST FAILED: {e.stderr.strip()}")
        grand[repo] = None
        continue

    for iss in issues:
        scanned += 1
        num = iss["number"]
        title = iss["title"]
        lids = sorted(l["name"] for l in iss["labels"] if lid_re.match(l["name"]))
        if not lids:
            continue
        already = any(title.startswith(f"({lid}) ") for lid in lids)
        cmd = ["gh","issue","edit",str(num),"-R",f"Prinzaessin86/{repo}"]
        if already:
            skipped += 1
            for lid in lids:
                cmd += ["--remove-label", lid]
        else:
            prefix = "".join(f"({lid}) " for lid in lids)
            cmd += ["--title", prefix + title]
            for lid in lids:
                cmd += ["--remove-label", lid]
        try:
            subprocess.run(cmd, capture_output=True, text=True, check=True)
            if not already:
                edited += 1
            removed += len(lids)
        except subprocess.CalledProcessError as e:
            failures += 1
            fail_nums.append(num)
            print(f"[{repo}] #{num} FAILED: {e.stderr.strip()}")

    grand[repo] = dict(scanned=scanned, edited=edited, removed=removed,
                       skipped=skipped, failures=failures, fail_nums=fail_nums)
    print(f"[{repo}] scanned={scanned} edited={edited} labels_removed={removed} "
          f"skipped_already={skipped} failures={failures} "
          f"{('fail#='+str(fail_nums)) if fail_nums else ''}")

print("=== SUMMARY JSON ===")
print(json.dumps(grand, indent=2))
PY
