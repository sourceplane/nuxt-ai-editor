#!/usr/bin/env bash
# hooks/render-deployment-docs.sh runs in the build box, which has python3 but
# not PyYAML. Console builds whose record hook imported yaml stopped at the
# record with exit 1 and their site live. This runs the hook on a scaffolded
# tree under a python3 with no third-party packages, and checks it renders
# the record — the workspace read from intent.yaml, the Workers named from
# .rebrand/values.json, the README section — the same with and without
# PyYAML. Offline: the probes find nothing, which the record says as
# "unreachable".
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

if grep -nE '^[^#]*\b(import|from) +yaml\b' "$here/hooks/render-deployment-docs.sh"; then
  echo "render.test.sh: the record hook imports yaml — the build box has no PyYAML" >&2; exit 1
fi
python3 -m venv --without-pip "$work/bare"
if "$work/bare/bin/python3" -c 'import yaml' 2>/dev/null; then
  echo "render.test.sh: the bare python3 still imports yaml — cannot test" >&2; exit 1
fi

site="$work/site"; mkdir -p "$site/.github/workflows" "$site/.rebrand" "$site/ai/context"
printf '{"reponame":"acme-notes","subdomain":"acme"}\n' > "$site/.rebrand/values.json"
printf '# acme-notes\n\nAn editor.\n\n## Live deployment\n\n<!-- 02-docs:begin -->\nNot recorded yet.\n<!-- 02-docs:end -->\n' > "$site/README.md"
printf '# operations\n' > "$site/ai/context/operations.md"
printf 'jobs:\n  lane:\n    steps:\n      - with:\n          version: v2.78.4\n' > "$site/.github/workflows/ci.yml"
cat > "$site/intent.yaml" <<'YAML'
execution:
  state:
    backendUrl: https://example.invalid
    workspace: ws_TEST0000   # the product's
environments:
  stage:
    env:
      BASE_DOMAIN: acme-notes.example.com
YAML

fail=0
for py in "$work/bare/bin" ""; do
  label="${py:+without PyYAML}"; label="${label:-with the system python3}"
  [ -n "$py" ] || python3 -c 'import yaml' 2>/dev/null || { echo "   (skipped: system python3 has no PyYAML)"; continue; }
  rm -f "$site/ai/context/deployment.md"
  # No workspace argument: the hook reads it from intent.yaml.
  if ! (cd "$site" && PATH="${py:+$py:}$PATH" bash "$here/hooks/render-deployment-docs.sh" . "" "$here" >/dev/null 2>"$work/err"); then
    echo "  ✕ $label: the hook failed"; sed 's/^/      /' "$work/err"; fail=1; continue
  fi
  rec="$site/ai/context/deployment.md"
  grep -q '| Orun workspace | `ws_TEST0000` |' "$rec" || { echo "  ✕ $label: the workspace was not read from intent.yaml"; fail=1; }
  grep -q 'https://acme-notes-web-stage.acme.workers.dev' "$rec" || { echo "  ✕ $label: the stage Worker URL is missing"; fail=1; }
  grep -q 'https://acme-notes-web-prod.acme.workers.dev/images/orun-probe-missing.png' "$rec" || { echo "  ✕ $label: the prod image probe is missing"; fail=1; }
  grep -q 'orun `v2.78.4`' "$rec" || { echo "  ✕ $label: the CI lane pin was not read"; fail=1; }
  grep -q 'This site is \*\*live\*\*' "$site/README.md" && [ "$(grep -c '<!-- 02-docs:begin -->' "$site/README.md")" = 1 ] \
    || { echo "  ✕ $label: the README section was not rendered once"; fail=1; }
  [ "$fail" = 0 ] && echo "   $label: record rendered, workspace read from intent.yaml"
done
[ "$fail" = 0 ] || exit 1
echo "render.test.sh: ok"
