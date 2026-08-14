#!/usr/bin/env python3
"""
Correlate open GitHub PRs with their Jira tickets and compute mergeability state.

Emits one JSON object per PR to stdout (JSON Lines). Claude reads this and renders
the grouped dashboard described in SKILL.md.

Data sources (both must be installed + authenticated):
  - gh   : GitHub CLI  (gh auth status)
  - jira  : ankitpokhrel/jira-cli  (jira me)

Config via env vars (all optional):
  PRJ_ORG            org to keep PRs from        (default: RoadRunnerEngineering)
  PRJ_RESOLVED       comma list of "resolved" Jira statuses that trigger the
                     codeowner-to-merge rule    (default: Done,Resolved)
  PRJ_REQUIRED       reviews needed for Ready-for-QA (default: 2)
  PRJ_KEY_PREFIXES   comma list of Jira project prefixes to look for in PR titles
                     (default: any [ABC-123] pattern)
  PRJ_ALL_TICKETS    when set (1/true/yes) — or pass --all — also emit a record
                     for every open (unresolved) ticket assigned to you that has
                     NO open PR, so the dashboard covers all in-flight work, not
                     just work with a PR. Default off keeps the run PR-focused.
"""
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ORG = os.environ.get("PRJ_ORG", "RoadRunnerEngineering")
RESOLVED = {s.strip() for s in os.environ.get("PRJ_RESOLVED", "Done,Resolved").split(",") if s.strip()}
REQUIRED = int(os.environ.get("PRJ_REQUIRED", "2"))
KEY_RE = re.compile(r"\[([A-Z][A-Z0-9]+-\d+)\]")         # ticket tag in PR title
BRANCH_KEY_RE = re.compile(r"^([A-Z][A-Z0-9]+-\d+)")     # ticket id qa-coder parses from a branch
CODER_HOST = os.environ.get("PRJ_CODER_HOST", "coder.dev.roadrunnerwm.com")
# Jira statuses that mean QA is happening / imminent, so a Coder env should exist.
QA_STATES = {s.strip() for s in os.environ.get("PRJ_QA_STATES", "Ready for QA").split(",") if s.strip()}
# Jira statuses meaning the ticket is already moving through QA/acceptance. A PR
# whose ticket is here is riding along awaiting QA sign-off — NOT a code-owner
# review. The code-owner gate only applies once the ticket resolves, so these
# must be kept distinct from "you still need to move it to QA".
QA_PIPELINE = {s.strip() for s in os.environ.get(
    "PRJ_QA_PIPELINE",
    "Ready for QA,Testing,In QA,Ready for Acceptance,In Acceptance,Acceptance",
).split(",") if s.strip()}
# Sweep all open assigned tickets (incl. ones with no PR), not just PR-backed work.
ALL_TICKETS = (os.environ.get("PRJ_ALL_TICKETS", "").strip().lower() in ("1", "true", "yes")
               or "--all" in sys.argv)


def run(cmd):
    """Run a command, return stdout (str). Empty string on failure."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""


def list_open_prs():
    out = run([
        "gh", "search", "prs", "--author=@me", "--state=open",
        "--json", "number,title,isDraft,repository,url,updatedAt", "--limit", "60",
    ])
    if not out:
        return []
    prs = json.loads(out)
    # Keep only PRs in the target org.
    return [p for p in prs if p["repository"]["nameWithOwner"].startswith(ORG + "/")]


def pr_reviews(pr):
    """Fetch review detail for one PR and merge into the dict."""
    repo = pr["repository"]["nameWithOwner"]
    out = run([
        "gh", "pr", "view", str(pr["number"]), "--repo", repo,
        "--json", "reviewDecision,latestReviews,mergeStateStatus,headRefName",
    ])
    approvals, changes_req = [], []
    review_decision, merge_state, branch = "", "", ""
    if out:
        d = json.loads(out)
        review_decision = d.get("reviewDecision", "") or ""
        merge_state = d.get("mergeStateStatus", "") or ""
        branch = d.get("headRefName", "") or ""
        for rv in d.get("latestReviews") or []:
            login = (rv.get("author") or {}).get("login", "?")
            if rv.get("state") == "APPROVED":
                approvals.append(login)
            elif rv.get("state") == "CHANGES_REQUESTED":
                changes_req.append(login)
    pr["approvals"] = approvals
    pr["changes_requested"] = changes_req
    pr["review_decision"] = review_decision
    pr["merge_state"] = merge_state
    pr["branch"] = branch
    bm = BRANCH_KEY_RE.match(branch)
    pr["branch_key"] = bm.group(1) if bm else None
    m = KEY_RE.search(pr["title"])
    if m:
        pr["jira_key"] = m.group(1)
        pr["key_source"] = "title"
    else:
        # Untagged title (e.g. "PT-1635 Foo" with no brackets, or no id at all).
        # Fall back to a bare leading id in the title, then to the branch prefix.
        # Without this the PR looks ticket-less, so every Jira gate below silently
        # goes unenforced and the PR can read as mergeable mid-QA.
        bare = BRANCH_KEY_RE.match(pr["title"])
        if bare:
            pr["jira_key"] = bare.group(1)
            pr["key_source"] = "title-untagged"
        elif pr["branch_key"]:
            pr["jira_key"] = pr["branch_key"]
            pr["key_source"] = "branch"
        else:
            pr["jira_key"] = None
            pr["key_source"] = None
    return pr


def jira_issues(jql):
    """Run a JQL query and return a list of normalized issue dicts.

    Uses `--raw` (the JSON API response) rather than `--plain` columns: jira-cli's
    plain output pads cells with extra tabs to align them, so single-tab splitting
    misaligns fields whenever a value is empty or short (e.g. an empty resolution
    on an open ticket). The raw JSON is unambiguous."""
    out = run(["jira", "issue", "list", "-q", jql, "--raw"])
    if not out:
        return []
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return []
    issues = data if isinstance(data, list) else data.get("issues", [])
    result = []
    for it in issues:
        f = it.get("fields", {})
        result.append({
            "key": it.get("key", ""),
            "status": (f.get("status") or {}).get("name", ""),
            # Jira sets `resolution` on any terminal state (Done, Won't Do,
            # Production Deployed, …) — the canonical "is this resolved?" signal,
            # more reliable than matching status-name strings.
            "resolution": (f.get("resolution") or {}).get("name", "") or "",
            "type": (f.get("issueType") or {}).get("name", ""),
            "summary": f.get("summary", "") or "",
        })
    return result


def jira_statuses(keys):
    if not keys:
        return {}
    q = "key in (" + ",".join(sorted(keys)) + ")"
    return {i["key"]: {k: i[k] for k in ("status", "resolution", "type", "summary")}
            for i in jira_issues(q)}


def jira_server():
    """Base URL from the jira-cli config, for building browse links. '' if unknown."""
    cfg = os.environ.get("JIRA_CONFIG_FILE", os.path.expanduser("~/.config/.jira/.config.yml"))
    try:
        with open(cfg) as f:
            for line in f:
                if line.startswith("server:"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return ""


def open_assigned_tickets():
    """Every open (unresolved) ticket assigned to the current user, PR or not.

    `resolution = EMPTY` is the canonical "still open" signal — it cleanly
    excludes Done / Resolved / Won't Do / Production Deployed, which all carry a
    resolution, without hardcoding this board's status names."""
    return jira_issues("assignee = currentUser() AND resolution = EMPTY")


def ticket_state(status, ttype):
    """Lane + action for a ticket that has no open PR."""
    if ttype == "Epic":
        return "epic", "Epic — tracking container"
    s = status.lower()
    if s in ("to do", "backlog", "open"):
        return "todo", "Not started — no PR yet"
    if s in ("refined", "ready", "selected for development"):
        return "refined", "Groomed, not started — no PR yet"
    if s == "in progress":
        return "in_progress", "In progress — no open PR yet"
    if s == "code review":
        return "review_no_pr", "In Code Review but no open PR found — did it merge?"
    if s in ("ready for qa", "testing", "ready for acceptance", "in qa", "in acceptance"):
        return "qa_no_pr", f"In {status} with no open PR — PR likely already merged"
    return "other_no_pr", f"{status} — no open PR"


def coder_user():
    """The Coder username, used to build workspace URLs. Falls back to $USER."""
    out = run(["coder", "whoami"])
    m = re.search(r"authenticated as (\S+)", out)
    return m.group(1) if m else os.environ.get("USER", "")


def coder_workspaces():
    """Map ticket-id -> workspace status from `coder list` (e.g. PT-1169 -> Started).

    qa-coder names each workspace `<TICKET>-qa-review`, so we key by that ticket
    id — the same id qa-coder derives from the branch."""
    out = run(["coder", "list"])
    ws = {}
    for line in out.splitlines():
        if "-qa-review" not in line:
            continue
        cols = line.split()
        name = cols[0].split("/")[-1]            # rporter/PT-1169-qa-review -> PT-1169-qa-review
        status = cols[2] if len(cols) > 2 else ""
        ticket = name[: -len("-qa-review")]
        ws[ticket] = status
    return ws


def coder_linked(jira_key):
    """True if the Jira ticket has a comment referencing a Coder env (the QA
    source of truth). Returns None if we can't tell."""
    if not jira_key:
        return None
    out = run(["jira", "issue", "view", jira_key, "--comments", "20", "--plain"])
    if not out:
        return None
    return CODER_HOST in out


def classify(pr):
    """Apply the workflow rules -> (state, action). Also flag mismatches."""
    approvals = len(set(pr["approvals"]))
    jira = pr.get("jira") or {}
    jstatus = jira.get("status", "")
    # Resolved = Jira's resolution field is set (canonical). Fall back to the
    # status-name list only when resolution is unavailable/empty.
    resolved = bool((jira.get("resolution") or "").strip()) or jstatus in RESOLVED
    merge = pr["merge_state"]
    # `mergeStateStatus == CLEAN` is the authoritative "GitHub will let you merge"
    # signal — it already reflects THIS repo's branch protection (required reviews,
    # code-owner rule if any, checks, up-to-date). Do NOT infer mergeability from
    # reviewDecision == APPROVED: in a repo with no code-owner rule (e.g. dsl),
    # normal approvals flip it to APPROVED with no code-owner review, and the PR
    # can still be BLOCKED. CLEAN is repo-agnostic and correct.
    ci_bad = merge in ("DIRTY", "UNSTABLE")
    flags = []

    if pr["isDraft"]:
        return "draft", "Draft — not ready for review", flags

    if pr["changes_requested"]:
        return "changes_requested", f"Address changes requested by {', '.join(sorted(set(pr['changes_requested'])))}", flags

    if approvals < REQUIRED:
        need = REQUIRED - approvals
        return "needs_review", f"Needs {need} more review{'s' if need != 1 else ''} (has {approvals}/{REQUIRED})", flags

    # approvals >= REQUIRED from here on. The path to merge is:
    #   approved -> move to QA -> QA/acceptance -> ticket resolves -> code-owner
    #   review -> GitHub reports CLEAN -> merge.
    # Order matters: the Jira stage gates BEFORE GitHub's CLEAN. A PR can be CLEAN
    # while its ticket is still in QA — merging then skips QA sign-off, exactly the
    # "don't skip ahead" failure. CLEAN only means "merge now" once the ticket has
    # resolved (or when there's no ticket to gate on at all).
    if resolved:
        if merge == "CLEAN":
            state, action = "mergeable", "Ticket resolved and GitHub reports it mergeable (all required reviews & checks passed) — ready to merge"
        elif (pr.get("review_decision") or "") == "APPROVED":
            # The review gate is already satisfied, so the remaining blocker is
            # mechanical — a rebase, a conflict, or a failing check — and nudging a
            # reviewer would be the wrong ask. NOTE: this is not inferring
            # mergeability from APPROVED (CLEAN still decides that above); it only
            # decides WHOSE action is next. On code-owner repos reviewDecision
            # cannot reach APPROVED until a code owner has signed off, so APPROVED
            # here means that step is done.
            if merge == "BEHIND":
                state, action = "needs_update", "Approved — branch is behind its base; update it and it should go CLEAN"
            elif merge == "DIRTY":
                state, action = "needs_update", "Approved — resolve merge conflicts, then it should go CLEAN"
            elif merge == "UNSTABLE":
                state, action = "needs_update", "Approved — required checks are failing; fix CI, then it should go CLEAN"
            else:
                state, action = "needs_update", f"Approved — no review action needed; merge state is {merge or 'unknown'}"
        else:
            state, action = "needs_codeowner", "Ticket resolved but PR still blocked — needs the final required (code-owner) review to merge"
            if merge == "BEHIND":
                flags.append("Also behind its base — will need an update after the review lands")
    elif jstatus in QA_PIPELINE:
        # Already moving through QA/acceptance: waiting on QA sign-off, not on a
        # code owner. Don't suggest a code-owner nudge here — nothing to merge
        # until the ticket resolves.
        state, action = "in_qa", f"In {jstatus} — awaiting QA/acceptance sign-off (no code-owner step until the ticket resolves)"
        if merge == "CLEAN":
            flags.append(f"GitHub says CLEAN but ticket is still in {jstatus} — do NOT merge ahead of QA sign-off")
    elif not jstatus:
        # No Jira ticket parsed from the title, so there's no stage to gate on —
        # GitHub's CLEAN is the only signal available.
        if merge == "CLEAN":
            state, action = "mergeable", "No Jira ticket on the PR title; GitHub reports it mergeable — ready to merge"
        else:
            state, action = "needs_review", f"No Jira ticket on the PR title; merge state is {merge or 'unknown'}"
    else:
        # Enough approvals but the ticket hasn't been moved into QA yet — this is
        # the actionable one: advance it (and stand up a QA env).
        state, action = "ready_for_qa", f"{approvals} approvals — move the ticket to Ready for QA"

    if ci_bad:
        flags.append(f"CI/merge state is {merge}")
    return state, action, flags


def main():
    prs = list_open_prs()
    if not prs and not ALL_TICKETS:
        print(json.dumps({"error": "no open PRs found (check `gh auth status`)"}))
        return
    with ThreadPoolExecutor(max_workers=8) as ex:
        prs = list(ex.map(pr_reviews, prs))
    statuses = jira_statuses({p["jira_key"] for p in prs if p["jira_key"]})
    for pr in prs:
        pr["jira"] = statuses.get(pr["jira_key"]) if pr["jira_key"] else None
        pr["state"], pr["action"], pr["flags"] = classify(pr)

    # QA / Coder coverage: a ticket "in or moving to Ready for QA" should have a
    # Coder env. Only fetch Coder data if any PR actually qualifies, so a normal
    # run with nothing near QA stays cheap.
    def qa_relevant(pr):
        return (pr["jira"] or {}).get("status") in QA_STATES or pr["state"] in ("ready_for_qa", "in_qa", "mergeable")

    relevant = [p for p in prs if qa_relevant(p)]
    workspaces, user = ({}, "")
    if relevant:
        workspaces, user = coder_workspaces(), coder_user()
        with ThreadPoolExecutor(max_workers=8) as ex:
            linked = dict(ex.map(lambda k: (k, coder_linked(k)),
                                 {p["jira_key"] for p in relevant if p["jira_key"]}))
    else:
        linked = {}

    for pr in prs:
        qa = None
        if qa_relevant(pr):
            # qa-coder names the workspace from the BRANCH ticket id; the dashboard
            # tracks the TITLE ticket id. Use the branch id for the env (so it
            # matches what qa-coder builds) and flag any divergence.
            ws_ticket = pr["branch_key"] or pr["jira_key"]
            ws_status = workspaces.get(ws_ticket)
            is_linked = linked.get(pr["jira_key"])
            if not ws_status:
                qa_state = "missing"
                pr["flags"].append(f"🧪 No QA Coder env — run: qa-coder {pr['branch']}")
            elif is_linked is False:
                qa_state = "not_linked"
                pr["flags"].append(f"🧪 Coder env exists ({ws_status}) but not linked on {pr['jira_key']} — post the CODER: comment")
            else:
                qa_state = "ok"
            if pr["branch_key"] and pr["jira_key"] and pr["branch_key"] != pr["jira_key"]:
                pr["flags"].append(f"⚠️ Branch says {pr['branch_key']} but ticket is {pr['jira_key']} — QA env will be named {ws_ticket}-qa-review. Do NOT rename the branch (it has an open PR — renaming closes it); just accept the env name or fix the PR title.")
            qa = {
                "state": qa_state,
                "workspace_ticket": ws_ticket,
                "workspace_status": ws_status,
                "linked_on_jira": is_linked,
                "url": f"https://{CODER_HOST}/@{user}/{ws_ticket}-qa-review" if user else None,
                "setup_cmd": f"qa-coder {pr['branch']}",
            }
        print(json.dumps({
            "kind": "pr",
            "repo": pr["repository"]["name"],
            "number": pr["number"],
            "url": pr["url"],
            "title": pr["title"],
            "branch": pr["branch"],
            "jira_key": pr["jira_key"],
            "jira_status": (pr["jira"] or {}).get("status"),
            "jira_summary": (pr["jira"] or {}).get("summary"),
            "approvals": sorted(set(pr["approvals"])),
            "approval_count": len(set(pr["approvals"])),
            "changes_requested": sorted(set(pr["changes_requested"])),
            "review_decision": pr["review_decision"],
            "merge_state": pr["merge_state"],
            "state": pr["state"],
            "action": pr["action"],
            "qa": qa,
            "flags": pr["flags"],
        }))

    # All-tickets sweep: emit a record for every open assigned ticket that has no
    # open PR, so the dashboard reflects all in-flight work. Tickets already tied
    # to a PR above are skipped (they're covered by their PR record).
    if ALL_TICKETS:
        covered = {p["jira_key"] for p in prs if p["jira_key"]}
        server = jira_server()
        for t in open_assigned_tickets():
            if t["key"] in covered:
                continue
            state, action = ticket_state(t["status"], t["type"])
            print(json.dumps({
                "kind": "ticket",
                "jira_key": t["key"],
                "jira_status": t["status"],
                "jira_summary": t["summary"],
                "jira_type": t["type"],
                "state": state,
                "action": action,
                "url": f"{server}/browse/{t['key']}" if server else None,
            }))


if __name__ == "__main__":
    main()
