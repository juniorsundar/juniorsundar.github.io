#!/usr/bin/env bash
# Checks for the CV document and the Tailored CV picker (issues #18, #23, #24).
# Usage: nix develop -c scripts/check-cv.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
check()    { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "  expected: $2"; echo "  actual:   $3"; fail=1; fi; }
contains() { case "$3" in *"$2"*) echo "ok   $1";; *) echo "FAIL $1: did not find '$2'"; fail=1;; esac; }
missing()  { case "$3" in *"$2"*) echo "FAIL $1: found '$2'"; fail=1;; *) echo "ok   $1";; esac; }

# Evaluate an expression against cv/cv.typ; the document's own <chosen>/<pages> metadata is the seam.
cvq() { # $1 = expression, $2 = optional --input value (e.g. selection=…)
  if [ -n "${2:-}" ]; then typst eval "$1" --root . --in cv/cv.typ --input phone= --input address= "--input=$2" 2>/dev/null
  else typst eval "$1" --root . --in cv/cv.typ --input phone= --input address= 2>/dev/null; fi
}
sel() { printf 'selection=%s' "$1"; }

echo "== CV document"
# Every Project, newest first (source order is curated, the CV sorts).
check "public CV has every Project, newest first" \
  '["refer.nvim","cling.nvim","neorg-extras","oxmpl","px4-log-tool","move_bot_sim","ur5_gripper_control"]' \
  "$(cvq 'query(<chosen>).first().value')"

check "empty selection has no Projects" '[]' "$(cvq 'query(<chosen>).first().value' "$(sel '[]')")"

# Full entries first, then the compact ones, each group newest first; an unknown slug is skipped, not an error.
check "selection filters, orders and drops unknown slugs" \
  '["cling.nvim","ur5_gripper_control","refer.nvim"]' \
  "$(cvq 'query(<chosen>).first().value' "$(sel '[{"slug":"refer.nvim","parts":["compact"]},{"slug":"ur5_gripper_control","parts":[]},{"slug":"nope","parts":[]},{"slug":"cling.nvim","parts":["tags"]}]')")"

pages=$(cvq 'query(<pages>).first().value.pages' "$(sel '[{"slug":"oxmpl","parts":[]}]')")
check "page count is a positive number" "yes" "$([ "$pages" -ge 1 ] 2>/dev/null && echo yes || echo no)"
fill=$(cvq 'query(<pages>).first().value.fill' "$(sel '[{"slug":"oxmpl","parts":[]}]')")
check "fill is a percentage" "yes" "$([ "$fill" -ge 0 ] && [ "$fill" -le 100 ] && echo yes || echo no)"

# The compact form stays on one line by falling back to the short name.
typst compile --root . --input phone= --input address= \
  --input "$(sel '[{"slug":"oxmpl","parts":["compact"]}]')" cv/cv.typ "$(mktemp -u /tmp/cvcheck-XXXX.pdf)" 2>/dev/null \
  && echo "ok   compact form compiles" || { echo "FAIL compact form compiles"; fail=1; }

echo "== Picker"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"; kill ${pid:-0} 2>/dev/null || true' EXIT
export XDG_DATA_HOME="$tmp/data" CV_PHONE=999888777 CV_ADDRESS="1 Test Street"
node cv/pick.mjs >"$tmp/pick.log" 2>&1 & pid=$!
for _ in $(seq 30); do grep -q 127.0.0.1 "$tmp/pick.log" 2>/dev/null && break; sleep 0.2; done
base=http://127.0.0.1:8765
# Fail fast: with a stray picker already on the port, the checks below would test that one instead of ours.
if ! grep -q 127.0.0.1 "$tmp/pick.log"; then
  echo "FAIL the picker did not start"; cat "$tmp/pick.log"; exit 1
fi
contains "picker reports its URL" "http://127.0.0.1:8765" "$(cat "$tmp/pick.log")"
missing  "picker did not open a browser in a non-tty run" "xdg-open" "$(cat "$tmp/pick.log")"

check "state lists every Project" "7" "$(curl -sf $base/state | grep -o '"slug"' | wc -l | tr -d ' ')"
check "build returns the page count" "2" "$(curl -sf -XPOST -d '{"picks":[{"slug":"oxmpl","parts":["compact"]}],"private":false}' $base/build | grep -o '"pages":[0-9]*' | cut -d: -f2)"
check "build reports dropped slugs" '["gone"]' "$(curl -sf -XPOST -d '{"picks":[{"slug":"gone","parts":[]}],"private":false}' $base/build | sed -n 's/.*"dropped":\(\[[^]]*\]\).*/\1/p')"

contains "save accepts a Selection" '"saved":"robotics-role"' \
  "$(curl -sf -XPOST -d '{"name":"robotics-role","picks":[{"slug":"oxmpl","parts":["tags"]}],"private":true}' $base/save)"
check "load round-trips it" '{"picks":[{"slug":"oxmpl","parts":["tags"]}],"private":true}' \
  "$(curl -sf "$base/selection?name=robotics-role" | tr -d '\n ')"
missing "saved Selection holds no phone number" "999888777" "$(cat "$tmp/data/cv-selections/robotics-role.json")"
check "state lists the saved Selection" "robotics-role" "$(curl -sf $base/state | grep -o '"selections":\["[^"]*"' | cut -d'"' -f4)"

curl -sf -XPOST -d '{"picks":[{"slug":"oxmpl","parts":[]}],"private":true}' $base/build >/dev/null
contains "private CV carries the phone number" "999888777" "$(curl -sf $base/cv.pdf | strings)"
curl -sf -XPOST -d '{"picks":[{"slug":"oxmpl","parts":[]}],"private":false}' $base/build >/dev/null
missing  "public CV does not" "999888777" "$(curl -sf $base/cv.pdf | strings)"

if command -v ss >/dev/null; then
  contains "picker listens on localhost only" "127.0.0.1:8765" "$(ss -ltn | grep 8765)"
fi
set +e
second=$(node cv/pick.mjs 2>&1); code=$?
set -e
check "a taken port fails loudly" "1" "$code"
contains "a taken port says why" "8765 is taken" "$second"

if command -v google-chrome-stable >/dev/null; then
  # The real page in a headless browser: rows rendered from /state, feedback text from /build, PDF embedded.
  dom=$(google-chrome-stable --headless --disable-gpu --no-sandbox --virtual-time-budget=15000 --dump-dom "$base/" 2>/dev/null || true)
  check "page renders every Project row" "7" "$(printf '%s' "$dom" | grep -o 'class="p" data-slug=' | wc -l | tr -d ' ')"
  check "page embeds the PDF" "yes" "$(printf '%s' "$dom" | grep -q 'iframe[^>]*src="/cv.pdf' && echo yes || echo no)"
  contains "page shows the page-count feedback" "last page" "$(printf '%s' "$dom" | grep -o 'last page [0-9]*% full' | head -1)"
fi

exit $fail
