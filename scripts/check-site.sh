#!/usr/bin/env bash
# Build-output checks for the content tools (archetype, project cards, garden links).
# Usage: nix develop -c scripts/check-site.sh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d); trap 'rm -rf "$out" content/posts/zz-archetype-check' EXIT
fail=0
check() { if grep -q -- "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
refute() { if grep -q -- "$2" "$3"; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi; }

# Archetype: a new bundle gets the decided front matter.
hugo new content posts/zz-archetype-check/index.md >/dev/null
f=content/posts/zz-archetype-check/index.md
check "archetype title from slug" 'title: "Zz Archetype Check"' "$f"
check "archetype summary"         '^summary: ""' "$f"
check "archetype tags"            '^tags: \[\]' "$f"
check "archetype draft"           '^draft: true' "$f"
rm -rf content/posts/zz-archetype-check

hugo -D --quiet --destination "$out/drafts" --baseURL https://juniorsundar.github.io/
hugo --quiet --destination "$out/live" --baseURL https://juniorsundar.github.io/
post="$out/drafts/posts/content-tools-sample/index.html"

# Garden links.
check  "garden link rewritten"   'href="https://jr-vault-site.vercel.app/pages/bootloader/"' "$post"
check  "garden link new tab"     'jr-vault-site.vercel.app/pages/bootloader/" target="_blank" rel="noopener"' "$post"
check  "garden link arrow"       'class="garden-link"' "$post"
check  "internal link untouched" 'href="/about/">' "$post"
refute "no garden: scheme leaks" 'href="garden:' "$post"
check  "garden anchor kept"      'href="https://jr-vault-site.vercel.app/pages/bootloader/#intro"' "$post"
check  "garden leading slash"    'href="https://jr-vault-site.vercel.app/pages/uses/"' "$post"
check  "javascript: neutralised" 'href="#ZgotmplZ"' "$post"

# Bundled media from bare file names.
check "bundled gif"   'src="/posts/content-tools-sample/demo.gif"' "$post"
check "bundled video" 'src="/posts/content-tools-sample/demo.mp4"' "$post"
[ -f "$out/drafts/posts/content-tools-sample/demo.gif" ] && echo "ok   gif published" || { echo "FAIL gif published"; fail=1; }

# Project cards and the featured row.
check  "projects page has cards"  'class="project-card' "$out/live/projects/index.html"
check  "featured row on home"     'class="featured-projects' "$out/live/index.html"
check  "featured row has a card"  'class="project-card' "$out/live/index.html"
check  "recent posts heading"     'class="recent-posts"' "$out/live/index.html"

# Drafts stay out of the live build.
[ ! -e "$out/live/posts/content-tools-sample" ] && echo "ok   draft excluded from live build" || { echo "FAIL draft excluded from live build"; fail=1; }

exit $fail
