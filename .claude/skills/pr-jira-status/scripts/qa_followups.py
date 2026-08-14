#!/usr/bin/env python3
"""Scan a PR's diff for QA follow-ups a fresh Coder env won't have on its own:

  1. Rake tasks the branch adds/changes — QA must run them in the env.
  2. Feature flags the branch introduces (Flipper) — must be created in the env.

A freshly-built Coder workspace only has the branch code checked out; one-off
rake tasks haven't run and new Flipper flags don't exist yet. This surfaces both
so the QA-handoff flow can offer to run them (see setup_qa.sh / SKILL.md).

Usage:
  qa_followups.py --repo owner/name --pr 123 [--workspace WS] [--json]
  qa_followups.py --branch some-branch [--workspace WS] [--json]

--branch resolves the open PR(s) for that branch via `gh search prs`. When
--workspace is given, each item includes a ready-to-run `coder ssh` command.

Detection is deliberately generous (better to remind than to miss). It flags:
  - changed `*.rake` files under lib/tasks (categorized by run_once /
    run_on_demand / run_none dir convention), and db/after_party/*.rb migrations;
  - added schema migrations (db/migrate/*.rb) -> `db:migrate` (the Coder
    checkout does NOT run migrations — that step is commented out in qa-setup.sh);
  - feature flags, from BOTH sides: backend `Flipper.*` usage AND frontend
    `useFeatureFlag(...)` hook calls / `feature_flags` API hits. The hook arg is
    resolved (literal, constant in the diff, or constant looked up in the repo).
    All flags are created in coyote's Flipper (FLIPPER_REPO) even for a
    frontend-only PR, since that's where the flag actually lives.
The exact rake invocation is best-effort (task name parsed from the diff, no
namespace assumed — matches this repo's one-off convention); a `verify` hint
(`rake -T | grep`) covers namespaced tasks.
"""
import argparse
import json
import os
import re
import subprocess
import sys

RAKE_TASK_RE = re.compile(r"""^\+?\s*task\s+:?["']?([A-Za-z_]\w*)["']?\s*(?:=>|:|\bdo\b|$)""")
# Flipper key from `Flipper.enabled?(:key`, `Flipper.enable(:key`, `Flipper[:key`, etc.
# `[?!]?` handles Ruby predicate/bang methods (enabled?, disable!).
FLIPPER_CALL_RE = re.compile(r"""Flipper\.\w+[?!]?\s*\(\s*["':]([A-Za-z_]\w*)""")
FLIPPER_INDEX_RE = re.compile(r"""Flipper\[\s*["':]([A-Za-z_]\w*)""")

# Feature flags are ALSO introduced from the frontend: lyra (and coyote's own
# webpack) gate on the Flipper-backed `/api/feature_flags` endpoint, reached via
# the `useFeatureFlag(feature)` hook. The string passed is the Flipper key
# (the controller feeds `names[]` straight into `Flipper.enabled?`), so a
# frontend-only PR still needs the flag CREATED in coyote's Flipper. The hook arg
# is often a constant, so we also resolve `CONST = 'value'` definitions.
FF_HOOK = os.environ.get("PRJ_FF_HOOK", "useFeatureFlag")
FF_ENDPOINT = os.environ.get("PRJ_FF_ENDPOINT", "feature_flags")
# Flags live in this repo's Flipper regardless of which repo's PR introduced them.
FLIPPER_REPO = os.environ.get("PRJ_FLIPPER_REPO", "coyote")
FRONTEND_EXTS = (".ts", ".tsx", ".js", ".jsx")
# Singular hook: useFeatureFlag(<literal> | <CONST>). Plural hook:
# useFeatureFlags([ <literals / CONSTs> ]) — array arg, often multi-line, so its
# regex runs over the per-file joined added text with DOTALL.
HOOK_LITERAL_RE = re.compile(re.escape(FF_HOOK) + r"""\(\s*["']([^"']+)["']""")
HOOK_IDENT_RE = re.compile(re.escape(FF_HOOK) + r"""\(\s*([A-Za-z_]\w*)\s*[),]""")
HOOK_PLURAL_RE = re.compile(re.escape(FF_HOOK) + r"""s\(\s*\[(.*?)\]""", re.DOTALL)
STRING_LIT_RE = re.compile(r"""["']([^"']+)["']""")
ARRAY_CONST_RE = re.compile(r"""\b([A-Z][A-Z0-9_]{2,})\b""")
CONST_DEF_RE = re.compile(r"""(?:export\s+)?const\s+([A-Za-z_]\w*)\s*=\s*["']([^"']+)["']""")
RUBY_CONST_RE = re.compile(r"""^\+?\s*([A-Z][A-Z0-9_]{2,})\s*=\s*["']([^"']+)["']""")


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""


def resolve_branch_prs(branch):
    """(repo, number) for every open PR the current user has on this branch."""
    out = run(["gh", "search", "prs", f"head:{branch}", "--author", "@me",
               "--state", "open", "--json", "number,repository"])
    if not out:
        return []
    try:
        rows = json.loads(out)
    except json.JSONDecodeError:
        return []
    return [(r["repository"]["nameWithOwner"], r["number"]) for r in rows]


def rake_category(path):
    if "/run_once/" in path:
        return "run_once"
    if "/run_on_demand/" in path:
        return "run_on_demand"
    if "/run_none/" in path:
        return "run_none"
    if path.startswith("db/after_party/"):
        return "after_party"
    return "other"


def scan_diff(diff):
    """Parse a unified diff -> (rake_items, flag_items)."""
    rake = {}          # task_name -> {task, category, file}
    after_party = None
    migration = None
    flags = {}          # resolved flag key -> {file, source}
    const_map = {}      # CONST name -> string value (for resolving hook args)
    hook_idents = []    # (identifier, file) from useFeatureFlag(IDENT) / array consts
    endpoint_hits = []  # files that call the feature_flags API directly
    frontend_added = {} # file -> [added lines] (hooks are parsed after the loop,
                        # since useFeatureFlags([...]) arrays can span lines)
    cur_file = None
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            cur_file = line[6:]
            continue
        if line.startswith("diff --git"):
            cur_file = None
            continue
        added = line.startswith("+") and not line.startswith("+++")
        if not added:
            continue

        # Rake: task definitions added inside a .rake file.
        if cur_file and cur_file.endswith(".rake"):
            m = RAKE_TASK_RE.match(line)
            if m:
                task = m.group(1)
                rake.setdefault(task, {"task": task, "category": rake_category(cur_file), "file": cur_file})
        # after_party data migration added -> single `after_party:run` follow-up.
        if cur_file and cur_file.startswith("db/after_party/") and cur_file.endswith(".rb"):
            after_party = cur_file
        # Schema migration added -> `db:migrate`. The Coder checkout does NOT run
        # migrations (that block is commented out in qa-setup.sh), so a branch's
        # new migration won't be applied until someone runs it in the env.
        if cur_file and cur_file.startswith("db/migrate/") and cur_file.endswith(".rb"):
            migration = cur_file

        # --- feature flags ---
        # Backend: Flipper references (any file).
        for rx in (FLIPPER_CALL_RE, FLIPPER_INDEX_RE):
            for key in rx.findall(line):
                flags.setdefault(key, {"file": cur_file, "source": "flipper"})
        # Constant definitions (TS `const X = '...'` and Ruby `X = '...'`) so we
        # can resolve hook args that are constants rather than literals.
        cm = CONST_DEF_RE.search(line)
        if cm:
            const_map[cm.group(1)] = cm.group(2)
        rm = RUBY_CONST_RE.match(line)
        if rm:
            const_map[rm.group(1)] = rm.group(2)
        # Frontend hook usage is parsed after the loop (multi-line arrays); here
        # just accumulate the added lines per frontend file.
        if cur_file and cur_file.endswith(FRONTEND_EXTS):
            frontend_added.setdefault(cur_file, []).append(line[1:])

    # Frontend feature flags: singular useFeatureFlag(...) and plural
    # useFeatureFlags([...]). Run over each file's joined added text so a
    # multi-line array is seen as one blob.
    for f, lines in frontend_added.items():
        text = "\n".join(lines)
        for key in HOOK_LITERAL_RE.findall(text):
            flags.setdefault(key, {"file": f, "source": "hook"})
        for ident in HOOK_IDENT_RE.findall(text):
            hook_idents.append((ident, f))
        for body in HOOK_PLURAL_RE.findall(text):
            for key in STRING_LIT_RE.findall(body):
                flags.setdefault(key, {"file": f, "source": "hook"})
            for ident in ARRAY_CONST_RE.findall(body):
                hook_idents.append((ident, f))
        if FF_ENDPOINT in text and any(t in text for t in ("fetch", "axios", "http", "getRequest", "/api/", "names")):
            endpoint_hits.append(f)

    # Resolve hook constants -> flag keys; anything unresolved is surfaced as-is.
    unresolved = []
    for ident, f in hook_idents:
        if ident in const_map:
            flags.setdefault(const_map[ident], {"file": f, "source": "hook"})
        else:
            unresolved.append({"ident": ident, "file": f})

    # Execution order matters: schema migrate -> after_party data migration ->
    # one-off tasks (backfills often depend on the new columns).
    rake_items = []
    if migration:
        rake_items.append({"task": "db:migrate", "category": "migration", "file": migration})
    if after_party:
        rake_items.append({"task": "after_party:run", "category": "after_party", "file": after_party})
    rake_items.extend(rake.values())

    flag_items = [{"key": k, "file": v["file"], "source": v["source"], "resolved": True}
                  for k, v in flags.items()]
    for u in unresolved:
        flag_items.append({"key": None, "ident": u["ident"], "file": u["file"],
                           "source": "hook-const", "resolved": False})
    for f in dict.fromkeys(endpoint_hits):  # dedup, keep order
        flag_items.append({"key": None, "file": f, "source": "endpoint", "resolved": False})
    return rake_items, flag_items


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RUNNER = os.path.join(SCRIPT_DIR, "run_in_coder.sh")


def coder_wrap(workspace, repo, inner):
    """A ready-to-run run_in_coder.sh invocation. The helper owns the tricky
    quoting + interactive-shell (asdf) wrapping; `inner` is single-quoted here so
    its double quotes (e.g. rails runner "...") survive."""
    return f"{RUNNER} {workspace} {repo.split('/')[-1]} '{inner}'"


def rake_verify(it):
    if it["category"] == "migration":
        return "bundle exec rake db:migrate:status | grep down"
    if it["category"] == "after_party":
        return "bundle exec rake after_party:status"
    return f"bundle exec rake -T | grep {it['task'].split(':')[0]}"


def enrich(items_rake, items_flag, repo, workspace):
    """Attach the bare in-repo command and (if workspace) the executor command."""
    for it in items_rake:
        it["repo"] = repo
        it["cmd"] = f"bundle exec rake {it['task']}"
        it["verify"] = rake_verify(it)
        if workspace:
            it["coder_cmd"] = coder_wrap(workspace, repo, it["cmd"])
    for it in items_flag:
        # Flags always live in coyote's Flipper (FLIPPER_REPO), even for a
        # lyra-only PR — the coyote+lyra pair shares one workspace with coyote
        # checked out. Only resolved keys get a create command.
        it["repo"] = FLIPPER_REPO
        if not it.get("resolved"):
            continue
        # Register-only default: create the flag but leave it OFF (QA toggles it).
        # Confirmed against the ActiveRecord adapter: add INSERTs a flipper_features
        # row (flag created + visible in the UI) with state=off.
        it["cmd"] = f'bundle exec rails runner "Flipper.add(:{it["key"]})"'
        it["enable_cmd"] = f'bundle exec rails runner "Flipper.enable(:{it["key"]})"'
        if workspace:
            it["coder_cmd"] = coder_wrap(workspace, FLIPPER_REPO, it["cmd"])


CAT_NOTE = {
    "migration": "schema migration — env does NOT auto-migrate, run db:migrate",
    "run_once": "run once in QA",
    "run_on_demand": "run to exercise the feature",
    "run_none": "⚠️ run_none — do NOT run this in QA",
    "after_party": "post-deploy data migration — run after_party:run",
    "other": "verify whether QA needs it",
}


def print_human(results):
    any_found = False
    for r in results:
        rake, flags = r["rake"], r["flags"]
        if not rake and not flags:
            continue
        any_found = True
        label = f"{r['repo'].split('/')[-1]}#{r['number']}"
        print(f"QA follow-ups detected in {label}:")
        for it in rake:
            print(f"  🔧 rake ({it['category']} — {CAT_NOTE.get(it['category'], '')}): {it['task']}")
            if it.get("coder_cmd"):
                print(f"       {it['coder_cmd']}")
            print(f"       verify: {it['verify']}")
        for it in flags:
            if it.get("resolved"):
                print(f"  🚩 flag: {it['key']}   (via {it['source']}; register-only, created off in {FLIPPER_REPO} — file: {it['file']})")
                if it.get("coder_cmd"):
                    print(f"       {it['coder_cmd']}")
                print(f"       enable instead: ...rails runner \"Flipper.enable(:{it['key']})\"")
            elif it["source"] == "hook-const":
                print(f"  🚩 flag (UNRESOLVED): {FF_HOOK}({it['ident']}) — couldn't resolve the constant to a key. "
                      f"Find its value, then Flipper.add it in {FLIPPER_REPO} (file: {it['file']})")
            else:  # endpoint
                print(f"  🚩 flag (endpoint): calls the {FF_ENDPOINT} API — confirm which flag(s) and Flipper.add them in {FLIPPER_REPO} (file: {it['file']})")
        print()
    if not any_found:
        print("No QA follow-ups detected (no rake tasks, migrations, or feature flags in the diff).")


CONST_VALUE_RE = re.compile(r"""["']([^"']+)["']""")


def resolve_const(repo, ident):
    """Best-effort: find `IDENT = '<value>'` in the repo's default branch via
    code search. Catches flag constants defined outside the PR diff (the common
    case — the constant already exists on main, the PR just references it)."""
    out = run(["gh", "search", "code", "--repo", repo, f"{ident} =",
               "--limit", "20", "--json", "textMatches"])
    if not out:
        return None
    try:
        rows = json.loads(out)
    except json.JSONDecodeError:
        return None
    pat = re.compile(re.escape(ident) + r"""\s*[:=]\s*["']([^"']+)["']""")
    for row in rows:
        for tm in row.get("textMatches", []):
            m = pat.search(tm.get("fragment", ""))
            if m:
                return m.group(1)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo")
    ap.add_argument("--pr", type=int)
    ap.add_argument("--branch")
    ap.add_argument("--workspace")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.repo and args.pr:
        targets = [(args.repo, args.pr)]
    elif args.branch:
        targets = resolve_branch_prs(args.branch)
    else:
        ap.error("provide --repo and --pr, or --branch")

    results = []
    for repo, number in targets:
        diff = run(["gh", "pr", "diff", str(number), "--repo", repo])
        rake, flags = scan_diff(diff)
        # Second-chance resolution for hook constants not defined in the diff:
        # look them up in the PR's repo (constants usually pre-exist on main).
        for it in flags:
            if not it.get("resolved") and it.get("source") == "hook-const":
                val = resolve_const(repo, it["ident"])
                if val:
                    it.update(key=val, resolved=True, source="hook")
        enrich(rake, flags, repo, args.workspace)
        results.append({"repo": repo, "number": number, "rake": rake, "flags": flags})

    if args.json:
        print(json.dumps(results))
    else:
        print_human(results)


if __name__ == "__main__":
    main()
