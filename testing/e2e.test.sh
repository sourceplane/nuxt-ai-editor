#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      install with the lockfile the product ships, render the wrangler
#      fixture and check the committed config IS that render, typecheck,
#      lint, test, build. The landing's own PR runs `plan` alone (an
#      `orun/BASE-*` branch), so THIS is where a product those steps refuse
#      is caught: before the tag, not after a build has merged it;
#   2. the stage web lane's own steps, rendered by `orun plan` in the product
#      and run IN THE TREE THE RUNNER STAGES for the job
#      (testing/lib/stage-job.py), with the dependency layout the pinned
#      composition produces and with the job's secrets in its environment as
#      the platform resolves them (the component's secretEnv, and its
#      optionalSecretEnv as an owner who has connected the AI Gateway would
#      have it): from a pull request's plan (the verify profile: the deploy
#      profile has no dry run) — `verify-app-structure` (which checks the
#      wrangler config exists BEFORE anything is built), `build-app` (the
#      component's buildCommand: the live wiring render, the build without
#      the optional secret, then the hand-off of that secret to the Worker,
#      which a verify lane — no Cloudflare credential — skips),
#      `verify-build-output` and `deploy-dry-run` (`wrangler deploy --dry-run
#      --name <reponame>-web-stage`); the bucket name in the built config
#      asserted to be the stage document's, not the fixture's, no built file
#      holding the optional secret, and the Worker within Workers Free;
#   3. serve the built Worker with `wrangler dev` (a local bucket behind BLOB,
#      and Workers AI — which has no local mode — a deterministic stand-in
#      behind AI, testing/lib/fake-ai): the component's OWN `smokeCommand`,
#      verbatim — the check the real deploy ends with — then every route the
#      editor promises: the page titled with the product's name; CSRF kept on
#      both writes; an inline completion and every toolbar rewrite (fix,
#      extend, reduce, simplify, summarize, translate) streamed from the AI
#      binding, an empty prompt and an oversized one refused; an image upload
#      written to R2 and served back byte for byte under a locked-down
#      Content-Security-Policy, a file that is not an image refused; an image
#      nobody uploaded a 404; then the owner's AI Gateway key handed to the
#      Worker as wrangler dev's .dev.vars (the same
#      tooling/wire/worker-secrets.mjs the deploy runs), the Worker serving
#      with it.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare tokens, apply the bucket and deploy for real, probe
# workers.dev — and call a real model. The R2 root is verified to
# `terraform validate` and its plan is part of every pull request's lanes;
# the apply needs an account. The stand-in proves the app's half of a
# completion (the route, the provider, the stream), not that a Workers AI
# model answers: that is only verified live. The gateway's model choice is
# tests/web's (models.test.ts): a test that served it would call Vercel.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). Several minutes: two installs and two
# builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
stop_group() {
  kill -TERM -- "-$1" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$1" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$1" 2>/dev/null || true
}
cleanup() {
  [ -z "$dev_pid" ] || stop_group "$dev_pid"
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NUXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step: what a pull request in the product
# verifies through its lanes, run here at once on the whole tree.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

# A job's steps out of a plan, by component and environment: each step's
# script (named by its id, or by a fixed name for the composition steps this
# file runs), the job's path, its env and the names of its secrets.
extract() { # PLAN COMPONENT ENV OUTDIR
  python3 - "$@" <<'PY'
import json, pathlib, re, sys
plan, comp, env, out = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3], pathlib.Path(sys.argv[4])
out.mkdir(parents=True, exist_ok=True)
job = next(j for j in plan["jobs"] if j["component"] == comp and j["environment"] == env)
for s in job["steps"]:
    run = s.get("run") or ""
    if not run:
        continue
    sid = s["id"]
    (out / f"{re.sub(r'[^A-Za-z0-9_-]', '_', sid)}.sh").write_text(run)
    if s["id"] in ("install-workspace-dependencies", "install-dependencies"):
        (out / "install.sh").write_text(run)
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or ".")
(out / "env").write_text("".join(f"export {k}={json.dumps(v)}\n" for k, v in (job.get("env") or {}).items()))
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
PY
}

# A job's private tree, staged as orun stages it. The source checkout carries
# no build output (nothing was built in it), and its dependencies are what the
# pinned composition says: a lane-scoped install ran once in the source tree
# and is linked in, or the job installs its own.
stage_job() { # STEPS-DIR WORK-DIR LOG
  local steps="$1" work="$2" log="$3"
  [ -f "$steps/install.sh" ] || { echo "FAIL: the lane has no install step" >&2; return 1; }
  if [ "$(cat "$steps/install.scope")" = lane ]; then
    (cd "$tree" && bash -e "$steps/install.sh") > "$log" 2>&1 \
      || { echo "FAIL: the lane's install step" >&2; tail -30 "$log" >&2; return 1; }
    python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
    [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; return 1; }
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
  else
    python3 "$here/lib/stage-job.py" "$tree" "$work"
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
    (cd "$work/$(cat "$steps/path")/$(cat "$steps/install.wd")" && bash -e "$steps/install.sh") > "$log" 2>&1 \
      || { echo "FAIL: the lane's install step" >&2; tail -30 "$log" >&2; return 1; }
    [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
      || { echo "FAIL: the job's install did not land inside its own tree" >&2; return 1; }
  fi
}

# One step, in the runner's per-job environment: the job's env (intent
# environment `env:`), its resolved secrets (exported by the caller) and
# ORUN_ENVIRONMENT; the step runs in the component's directory.
run_step() { # STEPS-DIR WORK-DIR STEP LOG
  local steps="$1" work="$2" step="$3" log="$4"
  [ -f "$steps/$step.sh" ] || { echo "FAIL: the stage lane has no $step step" >&2; return 1; }
  echo "   ▸ $step"
  if ! (cd "$work/$(cat "$steps/path")" && source "$steps/env" && export ORUN_ENVIRONMENT=stage \
        && bash -e "$steps/$step.sh") > "$log" 2>&1; then
    echo "FAIL: the lane's $step step" >&2; tail -40 "$log" >&2; return 1
  fi
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"
s01="$(git -C "$tree" rev-parse HEAD~1)"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# The landing's build is done; its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. the stage web lane's steps, in the job's own tree ──────────────────
# A pull request that changes the site: the lanes `orun plan` gives it.
git -C "$tree" checkout -q -b e2e-pr
echo "<!-- a change to the site's component -->" >> "$tree/apps/web/README.md"
git -C "$tree" -c user.email=e2e@example.invalid -c user.name=e2e commit -qam "a pull request"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base main --head HEAD --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
extract "$scratch/plan.json" web stage "$scratch/web"

# What the platform resolves into the job before its first step: the wiring
# document the R2 root lease-published (the component's secretEnv), with a
# bucket name no fixture carries, so the built config proves which document
# it came from.
r2_bucket="e2e-$repo-stage-bucket"
export WIRING_CLOUDFLARE_R2_STAGE='{"r2_bucket_name":"'"$r2_bucket"'"}'
export WIRING_CLOUDFLARE_R2_PROD='{"r2_bucket_name":"e2e-'"$repo"'-prod-bucket"}'

echo "── the stage web lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
for key in WIRING_CLOUDFLARE_R2_STAGE WIRING_CLOUDFLARE_R2_PROD; do
  grep -qx "$key" "$scratch/web/secrets" || { echo "FAIL: the stage web lane does not resolve $key" >&2; exit 1; }
done
if grep -q 'D1' "$scratch/web/secrets"; then
  echo "FAIL: the stage web lane resolves a D1 wiring document; the editor binds no database" >&2; exit 1
fi
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
stage_job "$scratch/web" "$work" "$scratch/install-web.log"
[ ! -e "$work/apps/web/.output" ] || { echo "FAIL: the staged tree carries build output" >&2; exit 1; }
# The optional secret as the platform resolves it for an owner who has set it
# (optionalSecretEnv): a canary no build may keep.
canary="e2e-canary-gateway-key"
for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
  if [ "$step" = build-app ]; then
    (export AI_GATEWAY_API_KEY="$canary" && run_step "$scratch/web" "$work" "$step" "$scratch/$step.log") || exit 1
  else
    run_step "$scratch/web" "$work" "$step" "$scratch/$step.log"
  fi
done
if grep -rlF "$canary" "$work/apps/web/.output" "$work/apps/web/.nuxt" "$work/apps/web/node_modules/.cache" 2>/dev/null | head -1 | grep -q .; then
  echo "FAIL: a built file holds AI_GATEWAY_API_KEY — the build must run without the optional secret" >&2; exit 1
fi
grep -q "worker-secrets: no Cloudflare credential in this job" "$scratch/build-app.log" \
  || { echo "FAIL: the verify lane's build did not leave the secret to the deploy lane" >&2; tail -10 "$scratch/build-app.log" >&2; exit 1; }
grep -q "\"$r2_bucket\"" "$work/apps/web/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage bucket from its wiring document" >&2; exit 1; }
grep -Eq "env\.BLOB \($r2_bucket\) +R2 Bucket" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind BLOB to the stage bucket" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
grep -Eq "env\.AI +AI" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind Workers AI as AI" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
if grep -Eq "D1 Database|KV Namespace" "$scratch/deploy-dry-run.log"; then
  echo "FAIL: the dry run binds a database or a namespace the editor never reads" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1
fi
size="$(grep -Eo 'Total Upload: [0-9.]+ KiB / gzip: [0-9.]+ KiB' "$scratch/deploy-dry-run.log" | head -1)"
gz="$(grep -Eo 'gzip: [0-9.]+ KiB' <<<"$size" | grep -Eo '[0-9.]+' || true)"
if [ -n "$gz" ] && python3 -c "import sys;sys.exit(0 if float(sys.argv[1]) <= 3072 else 1)" "$gz"; then :; else
  echo "FAIL: the Worker is ${size:-of unknown size} — over Workers Free's 3 MiB gzipped" >&2; exit 1
fi
echo "   the built config binds BLOB to the stage document's bucket ($r2_bucket) and AI to Workers AI;"
echo "   no built file holds the optional secret; the dry run accepts it — $size (Workers Free)"


# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the built Worker: BLOB on a local bucket, AI on the stand-in"
[ ! -e "$work/apps/web/.dev.vars" ] || { echo "FAIL: the staged tree carries a .dev.vars" >&2; exit 1; }
# The ONE change to the config the lane built with: the AI binding becomes a
# service binding to the Workers AI stand-in (Workers AI has no local mode),
# with the compatibility flag that lets the AbortSignal the stream passes to
# its model cross that RPC boundary (the real binding takes it natively).
# Everything else is the stage render build-app wrote.
python3 - "$work/apps/web/wrangler.jsonc" "$work/apps/web/wrangler.e2e.jsonc" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
swapped, n = re.subn(r'"ai":\s*\{\s*"binding":\s*"AI"\s*\}',
                     '"services": [{ "binding": "AI", "service": "fake-workers-ai", "entrypoint": "FakeAI" }]', text)
if n != 1:
    sys.exit("FAIL: the built config does not bind Workers AI as `\"ai\": { \"binding\": \"AI\" }`")
swapped, m = re.subn(r'"compatibility_flags":\s*\[', '"compatibility_flags": ["enable_abortsignal_rpc", ', swapped)
if m != 1:
    sys.exit("FAIL: the built config sets no compatibility_flags")
open(sys.argv[2], "w").write(swapped)
PY
cp -r "$here/lib/fake-ai" "$scratch/fake-ai"
start_dev() {
  port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
  iport=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
  (cd "$work/apps/web" && exec setsid pnpm exec wrangler dev -c wrangler.e2e.jsonc -c "$scratch/fake-ai/wrangler.jsonc" \
     --ip 127.0.0.1 --port "$port" --inspector-port "$iport" --show-interactive-dev-session=false) > "$scratch/dev.log" 2>&1 < /dev/null &
  dev_pid=$!
  url="http://127.0.0.1:$port"
  for _ in $(seq 1 120); do
    curl -s -o /dev/null "$url/favicon.ico" && break
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
    sleep 1
  done
  curl -s -o /dev/null "$url/favicon.ico" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
}
start_dev
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"

echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the editor" >&2; tail -20 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ every route the editor promises: completions through the AI binding, an image to R2 and back"
python3 - "$url" "$values" <<'PY' || { echo "FAIL: the routes; wrangler dev said:" >&2; tail -60 "$scratch/dev.log" >&2; exit 1; }
import base64, html, json, re, sys, urllib.error, urllib.request, uuid
base, values = sys.argv[1], json.load(open(sys.argv[2]))
name = values["productname"]
problems = []
def bad(m): problems.append(m)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None
opener = urllib.request.build_opener(NoRedirect)

class Visitor:
    # A browser of its own: its cookies (kept by hand — the CSRF cookie is
    # `__Host-` and Secure, which a cookie jar drops over http) and its token.
    def __init__(self):
        self.cookies = {}
        self.csrf = None
    def req(self, path, method="GET", body=None, headers=None, raw=None, timeout=60):
        h = dict(headers or {})
        data = raw
        if body is not None:
            data = json.dumps(body).encode()
            h["content-type"] = "application/json"
        if self.cookies:
            h["cookie"] = "; ".join(f"{k}={v}" for k, v in self.cookies.items())
        r = urllib.request.Request(base + path, data=data, method=method, headers=h)
        try:
            resp = opener.open(r, timeout=timeout)
        except urllib.error.HTTPError as e:
            resp = e
        for c in resp.headers.get_all("set-cookie") or []:
            k, _, v = c.split(";", 1)[0].partition("=")
            self.cookies[k.strip()] = v.strip()
        return resp.status, resp.headers, resp.read()
    def page(self, path="/"):
        s, h, body = self.req(path)
        text = body.decode("utf-8", "replace")
        m = re.search(r'<meta name="csrf-token" content="([^"]+)"', text)
        if m:
            self.csrf = m.group(1)
        return s, text
    def post(self, path, body=None, raw=None, headers=None, csrf=True):
        h = dict(headers or {})
        if csrf:
            h["csrf-token"] = self.csrf or ""
        return self.req(path, method="POST", body=body, raw=raw, headers=h)

MODEL = "@cf/zai-org/glm-4.7-flash"
CANNED = f"Canned answer from {MODEL}: the stand-in for Workers AI streamed this."

# ── the page, as its first visitor sees it ───────────────────────────────────
ada = Visitor()
s, page = ada.page("/")
m = re.search(r"<title>(.*?)</title>", page, re.S)
if s != 200 or not m or html.unescape(m.group(1)) != name:
    bad(f"/ answered {s}, titled {m and html.unescape(m.group(1))!r}, not {name!r}")
# Compared as text: the page's HTML escaping of the name (an apostrophe, an
# ampersand) need not be Python's, so each attribute is decoded first.
og = [html.unescape(c) for c in re.findall(r'<meta\b[^>]*\bproperty="og:title"[^>]*\bcontent="([^"]*)"', page)]
og += [html.unescape(c) for c in re.findall(r'<meta\b[^>]*\bcontent="([^"]*)"[^>]*\bproperty="og:title"', page)]
if og != [name]:
    bad(f"the Open Graph title is {og!r}, not exactly [{name!r}]")
if "Nuxt AI Editor" in page:
    bad("/ still carries the baseline's name")
if 'id="__nuxt"' not in page:
    bad("/ is not the Nuxt app")
if not ada.csrf or "__Host-csrf" not in ada.cookies:
    bad(f"/ carries no CSRF token or cookie (cookies: {sorted(ada.cookies)})")
# Collaboration stays off: no PartyKit host is configured, and ?room= is just a page.
if '"partykitHost":""' not in page.replace(" ", "") and 'partykitHost:""' not in page.replace(" ", ""):
    bad("the public runtime config carries a PartyKit host; collaboration must be off by default")
s, _ = ada.page("/?room=e2e")
if s != 200:
    bad(f"/?room=e2e answered {s}")
s, _, body = ada.req("/no-such-page")
if s != 404:
    bad(f"/no-such-page answered {s}, not 404")

# ── the completions, through the AI binding ─────────────────────────────────
s, _, body = ada.post("/api/completion", {"prompt": "The quick brown fox", "mode": "continue"}, csrf=False)
if s != 403:
    bad(f"a completion without the CSRF token answered {s}, not 403")
s, h, body = ada.post("/api/completion", {"prompt": "The quick brown fox", "mode": "continue"})
text = body.decode("utf-8", "replace")
if s != 200 or text != CANNED or not (h.get("content-type") or "").startswith("text/plain"):
    bad(f"the inline completion answered {s} {h.get('content-type')!r} {text[:120]!r}, not the stand-in's stream")
for mode in ("fix", "extend", "reduce", "simplify", "summarize", "translate"):
    body_in = {"prompt": "Teh editor is grate.", "mode": mode}
    if mode == "translate":
        body_in["language"] = "French"
    s, _, body = ada.post("/api/completion", body_in)
    if s != 200 or body.decode("utf-8", "replace") != CANNED:
        bad(f"the {mode} rewrite answered {s} {body[:120]!r}")
s, _, body = ada.post("/api/completion", {"mode": "fix"})
if s != 400:
    bad(f"a completion with no prompt answered {s}, not 400")
s, _, body = ada.post("/api/completion", {"prompt": "x" * 10001})
if s != 413:
    bad(f"a 10 001-character prompt answered {s}, not 413")

# ── an image, to R2 and back ─────────────────────────────────────────────────
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
def form(filename, ctype, data):
    b = "----e2e" + uuid.uuid4().hex
    raw = (f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\n'
           f"Content-Type: {ctype}\r\n\r\n").encode() + data + f"\r\n--{b}--\r\n".encode()
    return raw, {"content-type": f"multipart/form-data; boundary={b}"}
raw, hdrs = form("dot.png", "image/png", png)
s, _, body = ada.post("/api/upload", raw=raw, headers=hdrs, csrf=False)
if s != 403:
    bad(f"an upload without the CSRF token answered {s}, not 403")
s, _, body = ada.post("/api/upload", raw=raw, headers=hdrs)
objects = json.loads(body) if s == 200 else []
obj = objects[0] if isinstance(objects, list) and objects else {}
pathname = obj.get("pathname") or ""
if s != 200 or not re.fullmatch(r"dot-[A-Za-z0-9]+\.png", pathname):
    bad(f"the upload answered {s} {body[:200]!r}")
else:
    s, h, got = ada.req("/images/" + pathname)
    if s != 200 or got != png or (h.get("content-type") or "") != "image/png":
        bad(f"/images/{pathname} answered {s} {h.get('content-type')!r}, {len(got)} bytes (sent {len(png)})")
    if (h.get("content-security-policy") or "").strip() != "default-src 'none';":
        bad(f"/images/{pathname} is served with CSP {h.get('content-security-policy')!r}")
raw, hdrs = form("notes.txt", "text/plain", b"not an image")
s, _, body = ada.post("/api/upload", raw=raw, headers=hdrs)
if s == 200 or b"File type is invalid" not in body:
    bad(f"a text file upload answered {s} {body[:200]!r}; it must be refused as not an image")
s, _, _ = ada.req("/images/nobody-uploaded-this.png")
if s != 404:
    bad(f"an image nobody uploaded answered {s}, not 404")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   {name!r} served; an inline completion and six rewrites streamed through the AI binding, CSRF kept;")
print("   an image written to R2 and served back byte for byte, a text file refused, a missing image a 404")
PY

echo "   ▸ the owner's AI Gateway key on the Worker (worker-secrets.mjs --dev-vars, as the deploy sets it)"
stop_group "$dev_pid"; dev_pid=""
(cd "$work/apps/web" && AI_GATEWAY_API_KEY=e2e-gateway-key node ../../tooling/wire/worker-secrets.mjs --dev-vars .dev.vars \
   --secret AI_GATEWAY_API_KEY) > "$scratch/dev-vars.log" 2>&1 \
  || { echo "FAIL: worker-secrets.mjs --dev-vars" >&2; cat "$scratch/dev-vars.log" >&2; exit 1; }
# dotenv's double-quoted form, which wrangler dev reads; nothing else in it.
[ "$(cat "$work/apps/web/.dev.vars")" = 'AI_GATEWAY_API_KEY="e2e-gateway-key"' ] \
  || { echo "FAIL: .dev.vars does not hold exactly the gateway's key: $(sed 's/=.*/=…/' "$work/apps/web/.dev.vars")" >&2; exit 1; }
start_dev
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the editor did not serve with the gateway's key set" >&2; tail -20 "$scratch/dev.log" >&2; exit 1; }
echo "   the key reached the Worker as a secret, and the editor serves with it"
stop_group "$dev_pid"; dev_pid=""
rm -f "$work/apps/web/.dev.vars"

echo "e2e.test.sh: ok"
