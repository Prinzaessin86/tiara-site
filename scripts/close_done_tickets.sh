#!/usr/bin/env bash
# Close the 12 tickets the 2026-07-21 migration audit verified as ALREADY DONE / OBSOLETE.
# Matches each ticket by its Linear id in either a label OR the title, so it works whether or
# not move_lids.sh has run. Idempotent: already-closed issues are skipped.
#   bash scripts/close_done_tickets.sh
set -uo pipefail

python3 - <<'PY'
import json, re, subprocess

# repo -> list of Linear ids to close (audit "close now" list)
TARGETS = {
    "BloopPoop":   ["TEN-132", "TEN-130", "TEN-122"],
    "Bubbles":     ["PRI-149", "PRI-134", "PRI-133", "PRI-109", "PRI-112", "PRI-111", "PRI-110"],
    "SparkleReef": ["PRI-136", "PRI-142"],
}
NOTE = "Closing — verified ALREADY DONE / OBSOLETE in the 2026-07-21 Linear→GitHub migration audit (docs/LINEAR-MIGRATION-AUDIT-2026-07-21.md). Reopen if anything was missed."

def issues(repo):
    out = subprocess.run(
        ["gh","issue","list","-R",f"Prinzaessin86/{repo}","--state","open",
         "--limit","400","--json","number,title,labels"],
        capture_output=True, text=True, check=True).stdout
    return json.loads(out)

closed = notfound = failed = 0
for repo, lids in TARGETS.items():
    try:
        iss = issues(repo)
    except subprocess.CalledProcessError as e:
        print(f"[{repo}] LIST FAILED: {e.stderr.strip()}"); continue
    for lid in lids:
        rx = re.compile(rf'(^|\W){re.escape(lid)}(\W|$)')
        hit = next((i for i in iss
                    if any(l["name"] == lid for l in i["labels"]) or rx.search(i["title"])), None)
        if not hit:
            print(f"[{repo}] {lid}: no OPEN issue found (already closed?)"); notfound += 1; continue
        n = hit["number"]
        try:
            subprocess.run(["gh","issue","close",str(n),"-R",f"Prinzaessin86/{repo}",
                            "--comment",NOTE], capture_output=True, text=True, check=True)
            print(f"[{repo}] {lid}: closed #{n} — {hit['title'][:60]}"); closed += 1
        except subprocess.CalledProcessError as e:
            print(f"[{repo}] {lid}: CLOSE FAILED #{n}: {e.stderr.strip()}"); failed += 1

print(f"\n=== done: closed={closed} not_found={notfound} failed={failed} ===")
PY
