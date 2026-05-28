#!/usr/bin/env python3
"""Daily Todo + Routines — Claude-side CLI backed by Supabase.

Reads SUPABASE_URL + SUPABASE_SERVICE_KEY from ../.env and talks to the
Supabase PostgREST API. No external dependencies (stdlib only).

Examples:
  python3 scripts/todo.py today
  python3 scripts/todo.py task add "交报告" --due tomorrow
  python3 scripts/todo.py task list
  python3 scripts/todo.py task done 交报告
  python3 scripts/todo.py task rm 3f2a
  python3 scripts/todo.py routine add 网球 --days wed --icon 🎾
  python3 scripts/todo.py routine add 游泳 --days tue,thu --icon 🏊
  python3 scripts/todo.py routine list
  python3 scripts/todo.py routine log 网球                 # mark done today
  python3 scripts/todo.py routine log 游泳 --date 2026-05-26
  python3 scripts/todo.py routine log 网球 --undo
  python3 scripts/todo.py routine stats --weeks 8
"""
import os, sys, json, argparse, datetime
import urllib.request, urllib.parse, urllib.error

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env():
    p = os.path.join(PROJECT_ROOT, ".env")
    if os.path.exists(p):
        with open(p) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


load_env()
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_SERVICE_KEY") or os.environ.get("SUPABASE_ANON_KEY", "")


def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(1)


if not SUPABASE_URL or not KEY:
    die("Missing SUPABASE_URL / SUPABASE_SERVICE_KEY in .env (copy .env.example to .env and fill it in)")


def rest(method, table, params=None, body=None, prefer="return=representation"):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    if params:
        url += "?" + urllib.parse.urlencode(params, safe=",")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("apikey", KEY)
    req.add_header("Authorization", "Bearer " + KEY)
    req.add_header("Content-Type", "application/json")
    if prefer:
        req.add_header("Prefer", prefer)
    try:
        with urllib.request.urlopen(req) as r:
            txt = r.read().decode()
            return json.loads(txt) if txt.strip() else []
    except urllib.error.HTTPError as e:
        die(f"HTTP {e.code} on {method} {table}: {e.read().decode()}")


# ---------- date / weekday helpers ----------
WEEKDAY_MAP = {
    "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6, "sun": 7,
    "monday": 1, "tuesday": 2, "wednesday": 3, "thursday": 4,
    "friday": 5, "saturday": 6, "sunday": 7,
    "周一": 1, "周二": 2, "周三": 3, "周四": 4, "周五": 5, "周六": 6, "周日": 7, "周天": 7,
    "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7,
}
WEEKDAY_CN = {1: "周一", 2: "周二", 3: "周三", 4: "周四", 5: "周五", 6: "周六", 7: "周日"}


def parse_due(s):
    if not s:
        return None
    s = s.strip().lower()
    today = datetime.date.today()
    if s in ("today", "今天"):
        return today.isoformat()
    if s in ("tomorrow", "明天"):
        return (today + datetime.timedelta(days=1)).isoformat()
    if s in ("后天",):
        return (today + datetime.timedelta(days=2)).isoformat()
    if s.startswith("+") and s.endswith("d"):
        return (today + datetime.timedelta(days=int(s[1:-1]))).isoformat()
    if s in WEEKDAY_MAP:  # next occurrence of that weekday
        target, cur = WEEKDAY_MAP[s], today.isoweekday()
        diff = (target - cur) % 7 or 7
        return (today + datetime.timedelta(days=diff)).isoformat()
    return s  # assume ISO YYYY-MM-DD


def parse_days(s):
    out = []
    for part in s.replace("，", ",").replace("、", ",").split(","):
        p = part.strip().lower()
        if not p:
            continue
        if p not in WEEKDAY_MAP:
            die(f"Unknown weekday: {part}")
        out.append(WEEKDAY_MAP[p])
    return sorted(set(out))


def short(id_):
    return id_[:8]


# ---------- tasks ----------
def fetch_tasks(include_done=False):
    params = {"select": "*", "order": "due_date.asc.nullslast,created_at.asc"}
    if not include_done:
        params["done"] = "is.false"
    return rest("GET", "tasks", params)


def resolve_task(ref):
    ref = ref.strip()
    rows = fetch_tasks(include_done=True)
    for r in rows:
        if r["id"] == ref:
            return r
    pre = [r for r in rows if r["id"].startswith(ref)]
    if len(pre) == 1:
        return pre[0]
    sub = [r for r in rows if ref.lower() in r["title"].lower()]
    if len(sub) == 1:
        return sub[0]
    cands = pre or sub
    if not cands:
        die(f"No task matches '{ref}'")
    die("Ambiguous '" + ref + "' matches: " + ", ".join(f"{short(r['id'])} {r['title']}" for r in cands))


def cmd_task_add(a):
    body = {"title": a.title, "done": False, "source": "claude"}
    if a.due:
        body["due_date"] = parse_due(a.due)
    if a.notes:
        body["notes"] = a.notes
    r = rest("POST", "tasks", body=body)[0]
    due = f" (due {r['due_date']})" if r.get("due_date") else ""
    print(f"✅ Added: {r['title']}{due}  [{short(r['id'])}]")


def cmd_task_list(a):
    rows = fetch_tasks(include_done=a.all)
    if not rows:
        print("(no tasks)")
        return
    for r in rows:
        box = "☑" if r["done"] else "☐"
        due = f" ⏰{r['due_date']}" if r.get("due_date") else ""
        print(f"{box} [{short(r['id'])}] {r['title']}{due}")


def cmd_task_done(a):
    r = resolve_task(a.ref)
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    rest("PATCH", "tasks", params={"id": f"eq.{r['id']}"},
         body={"done": True, "completed_at": now})
    print(f"✔ Done: {r['title']}")


def cmd_task_rm(a):
    r = resolve_task(a.ref)
    rest("DELETE", "tasks", params={"id": f"eq.{r['id']}"})
    print(f"🗑 Removed: {r['title']}")


# ---------- routines ----------
def fetch_routines(active_only=True):
    params = {"select": "*", "order": "created_at.asc"}
    if active_only:
        params["active"] = "is.true"
    return rest("GET", "routines", params)


def resolve_routine(ref):
    ref = ref.strip()
    rows = fetch_routines(active_only=False)
    for r in rows:
        if r["id"] == ref:
            return r
    pre = [r for r in rows if r["id"].startswith(ref)]
    if len(pre) == 1:
        return pre[0]
    sub = [r for r in rows if ref.lower() in r["name"].lower()]
    if len(sub) == 1:
        return sub[0]
    cands = pre or sub
    if not cands:
        die(f"No routine matches '{ref}'")
    die("Ambiguous '" + ref + "': " + ", ".join(f"{short(r['id'])} {r['name']}" for r in cands))


def cmd_routine_add(a):
    days = parse_days(a.days)
    body = {"name": a.name, "weekdays": days, "active": True}
    if a.icon:
        body["icon"] = a.icon
    r = rest("POST", "routines", body=body)[0]
    dd = "、".join(WEEKDAY_CN[d] for d in days)
    print(f"✅ Routine added: {r.get('icon') or ''}{r['name']} ({dd})  [{short(r['id'])}]")


def cmd_routine_list(a):
    rows = fetch_routines(active_only=not a.all)
    if not rows:
        print("(no routines)")
        return
    for r in rows:
        dd = "、".join(WEEKDAY_CN[d] for d in r["weekdays"])
        print(f"{r.get('icon') or ''}[{short(r['id'])}] {r['name']} — {dd}")


def cmd_routine_rm(a):
    r = resolve_routine(a.ref)
    rest("DELETE", "routines", params={"id": f"eq.{r['id']}"})
    print(f"🗑 Routine removed: {r['name']}")


def cmd_routine_log(a):
    r = resolve_routine(a.ref)
    date = parse_due(a.date) if a.date else datetime.date.today().isoformat()
    if a.undo:
        rest("DELETE", "routine_logs",
             params={"routine_id": f"eq.{r['id']}", "date": f"eq.{date}"})
        print(f"↩ Unlogged {r['name']} on {date}")
        return
    rest("POST", "routine_logs", params={"on_conflict": "routine_id,date"},
         body={"routine_id": r["id"], "date": date, "done": True},
         prefer="resolution=merge-duplicates,return=representation")
    print(f"✔ Logged {r.get('icon') or ''}{r['name']} on {date}")


def cmd_routine_stats(a):
    today = datetime.date.today()
    start = today - datetime.timedelta(weeks=a.weeks)
    routines = fetch_routines(active_only=True)
    if not routines:
        print("(no routines)")
        return
    logs = rest("GET", "routine_logs", {"select": "*", "date": f"gte.{start.isoformat()}"})
    by_r = {}
    for l in logs:
        if l["done"]:
            by_r.setdefault(l["routine_id"], set()).add(l["date"])
    print(f"坚持度（最近 {a.weeks} 周，✓=完成 ·=漏掉）")
    for r in routines:
        done_dates = by_r.get(r["id"], set())
        sched = []
        d = start
        while d <= today:
            if d.isoweekday() in r["weekdays"]:
                sched.append(d)
            d += datetime.timedelta(days=1)
        total = len(sched)
        done = sum(1 for d in sched if d.isoformat() in done_dates)
        pct = int(round(100 * done / total)) if total else 0
        marks = "".join("✓" if d.isoformat() in done_dates else "·" for d in sched)
        dd = "、".join(WEEKDAY_CN[x] for x in r["weekdays"])
        print(f"\n{r.get('icon') or ''}{r['name']} ({dd})  {done}/{total}  {pct}%")
        print(f"  {marks}")


def cmd_today(a):
    today = datetime.date.today()
    iso = today.isoweekday()
    print(f"📅 {today.isoformat()} {WEEKDAY_CN[iso]}")
    print("── 今日待办 ──")
    tasks = fetch_tasks(include_done=False)
    todays = [t for t in tasks if not t.get("due_date") or t["due_date"] <= today.isoformat()]
    if not todays:
        print("  (无)")
    for t in todays:
        due = f" ⏰{t['due_date']}" if t.get("due_date") else ""
        print(f"  ☐ [{short(t['id'])}] {t['title']}{due}")
    print("── 今日 routine ──")
    routines = [r for r in fetch_routines(active_only=True) if iso in r["weekdays"]]
    if not routines:
        print("  (今天无)")
        return
    logs = rest("GET", "routine_logs", {"select": "*", "date": f"eq.{today.isoformat()}"})
    done_ids = {l["routine_id"] for l in logs if l["done"]}
    for r in routines:
        mark = "✔" if r["id"] in done_ids else "☐"
        print(f"  {mark} {r.get('icon') or ''}{r['name']}")


def main():
    p = argparse.ArgumentParser(prog="todo")
    sub = p.add_subparsers(dest="cmd")

    sub.add_parser("today").set_defaults(func=cmd_today)

    pt = sub.add_parser("task")
    ts = pt.add_subparsers(dest="sub")
    a = ts.add_parser("add"); a.add_argument("title"); a.add_argument("--due"); a.add_argument("--notes"); a.set_defaults(func=cmd_task_add)
    a = ts.add_parser("list"); a.add_argument("--all", action="store_true"); a.set_defaults(func=cmd_task_list)
    a = ts.add_parser("done"); a.add_argument("ref"); a.set_defaults(func=cmd_task_done)
    a = ts.add_parser("rm"); a.add_argument("ref"); a.set_defaults(func=cmd_task_rm)

    pr = sub.add_parser("routine")
    rs = pr.add_subparsers(dest="sub")
    a = rs.add_parser("add"); a.add_argument("name"); a.add_argument("--days", required=True); a.add_argument("--icon"); a.set_defaults(func=cmd_routine_add)
    a = rs.add_parser("list"); a.add_argument("--all", action="store_true"); a.set_defaults(func=cmd_routine_list)
    a = rs.add_parser("rm"); a.add_argument("ref"); a.set_defaults(func=cmd_routine_rm)
    a = rs.add_parser("log"); a.add_argument("ref"); a.add_argument("--date"); a.add_argument("--undo", action="store_true"); a.set_defaults(func=cmd_routine_log)
    a = rs.add_parser("stats"); a.add_argument("--weeks", type=int, default=8); a.set_defaults(func=cmd_routine_stats)

    args = p.parse_args()
    if not hasattr(args, "func"):
        p.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()
