#!/bin/bash
# Ingress gateway janitor: reads this gateway's HAProxy log and blocks abusive client IPs through
# the haproxy.cfg.d/00-security-blocklist fragments (+ -http), then runs task#mergecfg.
# Stored as the key janitor.sh of <ns>/cfg/<gw> (projected into /scripts/ like gencfg.sh),
# run by task#janitor of <ns>/svc/<gw>.
# Usage: janitor.sh [<ns> <gw>]   env: JANITOR_DRYRUN=1, JANITOR_SINCE=<logs --since>, JANITOR_UNTIL=<logs --until>
# Keys of <ns>/cfg/<gw>: janitor.enabled (false = off), janitor.allowlist (one IP/CIDR per line),
#                        janitor.webhook (Mattermost or Slack incoming webhook, optional), janitor.state (managed).
set -uo pipefail
NS=${1:-${OPENSVC_NAMESPACE:-}}; GW=${2:-${OPENSVC_SVCNAME:-haproxy}}
[ -n "$NS" ] || { echo "janitor: namespace unknown"; exit 1; }
CFG=$NS/cfg/$GW; SVC=$NS/svc/$GW
if om $CFG key list >/dev/null 2>&1; then
  dec() { om $CFG key decode --name "$1" 2>/dev/null; }
  put() { om $CFG key change --name "$1" --from "$2" >/dev/null 2>&1 || om $CFG key add --name "$1" --from "$2" >/dev/null; }
else
  dec() { om $CFG decode --key "$1" 2>/dev/null; }
  put() { om $CFG change --key "$1" --from "$2" >/dev/null 2>&1 || om $CFG add --key "$1" --from "$2" >/dev/null; }
fi
[ "$(dec janitor.enabled | tr -d '[:space:]')" = "false" ] && { echo "janitor: disabled (janitor.enabled=false)"; exit 0; }
RT=$(command -v docker || command -v podman) || { echo "janitor: neither docker nor podman found"; exit 1; }
C=$($RT ps --format '{{.Names}}' | grep -E "^${NS}\.\.${GW}\.container\.[0-9]+$" | while read -r n; do $RT inspect -f '{{.Config.Image}} {{.Name}}' "$n"; done | awk '$1 ~ /haproxy/ {sub("/","",$2); print $2; exit}')
[ -n "$C" ] || { echo "janitor: no haproxy container of $SVC on $(hostname), nothing to read"; exit 0; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
$RT logs --since "${JANITOR_SINCE:-6m}" ${JANITOR_UNTIL:+--until "$JANITOR_UNTIL"} "$C" > $W/log 2>&1 || true
dec janitor.state > $W/state || true
dec janitor.allowlist > $W/allow || true
dec haproxy.cfg > $W/merged || true
python3 - "$W" "${JANITOR_DRYRUN:-0}" "$NS/$GW" <<'PY'
import sys, re, json, time, ipaddress, os
W, dry, gw = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
now = int(time.time())
WINDOW_AUTH, WINDOW_SCAN = 20, 30            # thresholds within the log window (~5 min)
TTL, TTL_REPEAT, MAX_ENTRIES = 86400, 7 * 86400, 5000
line_re = re.compile(r'(?P<ip>(?:\d{1,3}\.){3}\d{1,3}|[0-9a-f:]+):\d+ \[[^\]]+\] \S+ \S+ \S+ (?P<st>\d{3}) .*?"(?P<m>[A-Z]+) (?P<u>\S+)')
auth_re = re.compile(r'/api/(login|tokens)|/protocol/openid-connect/token|/login-actions/authenticate')
scan_re = re.compile(r'/\.(env|git|svn|ssh|aws|npmrc|vscode|bash_history)|wp-config|id_(rsa|ed25519)|\.sql(\?|$)|phpinfo|/actuator/|secrets?\.(json|yml)|docker-compose', re.I)
watch_re = re.compile(r'/admin/master|/api/mcp')
def norm(ip):
    return ip[7:] if ip.startswith("::ffff:") else ip
allow = [ipaddress.ip_network(x) for x in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "::1/128")]
for l in open(W + "/allow", errors="replace"):
    l = l.split("#")[0].strip()
    if l:
        try: allow.append(ipaddress.ip_network(l, strict=False))
        except ValueError: pass
def allowed(ip):
    try: a = ipaddress.ip_address(ip)
    except ValueError: return True
    return any(a in n for n in allow)
try: st = json.load(open(W + "/state"))
except Exception: st = {}
blocks, strikes = st.get("blocks", {}), st.get("strikes", {})
auth, scan, watch = {}, {}, {}
for l in open(W + "/log", errors="replace"):
    m = line_re.search(l)
    if not m: continue
    ip, code, meth, url = norm(m["ip"]), int(m["st"]), m["m"], m["u"]
    path = re.sub(r"^https?://[^/]+", "", url).split("?")[0]
    if allowed(ip): continue
    if auth_re.search(path) and (code in (400, 401, 403, 429) or (meth == "POST" and "/login-actions/authenticate" in path and code == 200)):
        auth[ip] = auth.get(ip, 0) + 1
    if scan_re.search(path):
        scan[ip] = scan.get(ip, 0) + 1
    if watch_re.search(path):
        watch.setdefault(ip, set()).add(path[:40])
changed, events = False, []
for ip in list(blocks):
    if blocks[ip].get("expires", 0) and blocks[ip]["expires"] < now:
        events.append("unblocked %s (expired, %s)" % (ip, blocks[ip].get("reason", "")))
        del blocks[ip]; changed = True
for ip, n, why, th in [(i, n, "auth failures", WINDOW_AUTH) for i, n in auth.items()] + [(i, n, "secret-file probes", WINDOW_SCAN) for i, n in scan.items()]:
    if n < th or ip in blocks: continue
    strikes[ip] = strikes.get(ip, 0) + 1
    ttl = TTL_REPEAT if strikes[ip] > 1 else TTL
    blocks[ip] = {"since": now, "expires": now + ttl, "reason": "%d %s" % (n, why), "strikes": strikes[ip]}
    events.append("BLOCKED %s for %dh: %d %s in the window (strike %d)" % (ip, ttl // 3600, n, why, strikes[ip]))
    changed = True
for ip, paths in watch.items():
    if ip not in blocks:
        events.append("ALERT %s reached %s (not blocked automatically)" % (ip, ", ".join(sorted(paths))))
if len(blocks) > MAX_ENTRIES:   # bounded: drop the oldest automatic entries, never the manual ones
    auto = sorted([i for i in blocks if blocks[i].get("expires", 0)], key=lambda i: blocks[i]["since"])
    for i in auto[: len(blocks) - MAX_ENTRIES]:
        del blocks[i]; changed = True
    events.append("WARNING blocklist over %d entries, oldest automatic ones dropped" % MAX_ENTRIES)
if len(strikes) > 4 * MAX_ENTRIES:
    strikes = dict(sorted(strikes.items(), key=lambda kv: kv[1], reverse=True)[: 2 * MAX_ENTRIES])
print("janitor %s: %d log lines, %d IPs with auth failures, %d probing, %d blocked (%s)" % (
    gw, sum(1 for _ in open(W + "/log", errors="replace")), len(auth), len(scan), len(blocks), "dry-run" if dry else ("changed" if changed else "unchanged")))
top = sorted(auth.items(), key=lambda kv: -kv[1])[:5]
if top: print("  top auth failures:", ", ".join("%s=%d" % kv for kv in top))
top = sorted(scan.items(), key=lambda kv: -kv[1])[:5]
if top: print("  top probes:", ", ".join("%s=%d" % kv for kv in top))
for e in events: print("  " + e)
json.dump({"blocks": blocks, "strikes": strikes, "updated": now}, open(W + "/state.new", "w"), indent=1, sort_keys=True)
open(W + "/changed", "w").write("1" if changed and not dry else "0")
open(W + "/events", "w").write("\n".join(events))
ips = sorted(blocks)
acl = " ".join(sum([[i, "::ffff:" + i] if ":" not in i else [i] for i in ips], []))
hosts = re.findall(r"hdr\(host\) -i ([a-z0-9.-]+\.[a-z]{2,})", open(W + "/merged", errors="replace").read())
open(W + "/certhost", "w").write(hosts[0] if hosts else "")
open(W + "/acl", "w").write(acl)
PY
[ "$(cat $W/changed)" = "1" ] || exit 0
CERTHOST=$(cat $W/certhost); ACL=$(cat $W/acl)
put janitor.state $W/state.new
for fe in https http; do
  dec haproxy.cfg.head | grep -q "^frontend $fe\$" || continue
  sfx=""; [ $fe = http ] && sfx=-http
  {
    printf "frontend %s\n    # security blocklist, managed by janitor.sh (key janitor.state): rejected at connection, IPv4 and IPv4-mapped\n" $fe
    # a gencfg.sh older than the empty-FQDNS fix exits 1 on a frontend patch naming no host: name one that already has its cert
    [ -n "$CERTHOST" ] && printf "    # hdr(host) -i %s (existing certificate, nothing issued)\n" "$CERTHOST"
    [ -n "$ACL" ] && printf "    tcp-request connection reject if { src %s }\n" "$ACL"
    true
  } > $W/frag$sfx
  put haproxy.cfg.d/00-security-blocklist$sfx $W/frag$sfx
done
om $SVC run --rid task#mergecfg 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E "configuration is|updated|ERROR|exited with code" | tail -2
URL=$(dec janitor.webhook | tr -d '[:space:]')
if [ -n "$URL" ] && [ -s $W/events ]; then
  python3 - "$URL" "$NS/$GW" < $W/events <<'PY'
import sys, json, urllib.request
url, gw = sys.argv[1], sys.argv[2]
text = "\n".join("- " + l for l in sys.stdin.read().splitlines() if l.strip())
if text:
    try:
        urllib.request.urlopen(urllib.request.Request(url, data=json.dumps({"username": "janitor", "text": "**gateway %s**\n%s" % (gw, text)}).encode(), headers={"Content-Type": "application/json"}), timeout=10)
    except Exception as e:
        print("janitor: webhook failed: %s" % e)
PY
fi
