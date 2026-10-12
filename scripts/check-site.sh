#!/usr/bin/env bash
# Build-output checks for the content tools (archetype, project cards, garden links).
# Usage: nix develop -c scripts/check-site.sh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d); trap 'rm -rf "$out" content/posts/zz-archetype-check; cp "$out/projects.yaml" data/projects.yaml 2>/dev/null || true' EXIT
fail=0
check() { if grep -q -- "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
refute() { if grep -q -- "$2" "$3"; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi; }
same() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; echo "  expected: $2"; echo "  actual:   $3"; fail=1; fi; }

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
check  "bare garden: is the root" 'href="https://jr-vault-site.vercel.app/"' "$out/live/about/index.html"
check  "javascript: neutralised" 'href="#ZgotmplZ"' "$post"

# Bundled media from bare file names.
check "bundled gif"   'src="/posts/content-tools-sample/demo.gif"' "$post"
check "bundled video" 'src="/posts/content-tools-sample/demo.mp4"' "$post"
[ -f "$out/drafts/posts/content-tools-sample/demo.gif" ] && echo "ok   gif published" || { echo "FAIL gif published"; fail=1; }

# Project cards and the featured row.
check  "about renders cv entries" 'class="cv-entry"' "$out/live/about/index.html"
check  "about links the cv pdf"   'href="/cv.pdf"' "$out/live/about/index.html"
refute "no phone on about"        '+971' "$out/live/about/index.html"
check  "projects page has cards"  'class="project-card' "$out/live/projects/index.html"
check  "featured row on home"     'class="featured-projects' "$out/live/index.html"
check  "featured row has a card"  'class="project-card' "$out/live/index.html"
check  "card shows the summary"   'project-desc">Sampling-based motion planners in Rust' "$out/live/projects/index.html"

# About page: every Project in CV form, newest first, in the same section order as the PDF.
about="$out/live/about/index.html"
cp data/projects.yaml "$out/projects.yaml"
proj=$(sed -n '/id="projects"/,/id="certifications"/p' "$about")
same "about projects: every Project, newest first" \
  "https://github.com/juniorsundar/refer.nvim https://github.com/juniorsundar/cling.nvim https://github.com/juniorsundar/neorg-extras https://github.com/juniorsundar/oxmpl https://github.com/tiiuae/px4-log-tool https://github.com/juniorsundar/move_bot_sim https://github.com/juniorsundar/ur5_gripper_control " \
  "$(printf '%s\n' "$proj" | grep -o 'href="https://github.com/[^"]*"' | sed 's/href="//;s/"$//' | tr '\n' ' ')"
check  "about projects: role shown"    'class="cv-sub">Developer/Maintainer' "$about"
check  "about projects: dates shown"   'February 2026 - Present' "$about"
check  "about projects: tags shown"    'class="cv-tags"' "$about"
check  "about projects: heading links to the card view" 'class="cv-more" href="/projects/"' "$about"
same "about sections match the PDF order" "yes" \
  "$([ "$(grep -n 'id="certifications"' "$about" | cut -d: -f1)" -lt "$(grep -n 'id="publications"' "$about" | cut -d: -f1)" ] && echo yes || echo no)"

# A Project with no image builds and renders a text-only card.
printf '\n- slug: text-only-check\n  name: text-only-check\n  summary: A Project with no image.\n  link: https://example.com/x\n  start: "2020-01"\n' >> data/projects.yaml
if hugo --quiet --destination "$out/noimg" --baseURL https://juniorsundar.github.io/; then
  sed -n '/text-only-check/,/<\/a>/p' "$out/noimg/projects/index.html" > "$out/card.html"
  check  "card without an image still shows"  'project-name">text-only-check' "$out/card.html"
  refute "card without an image has no <img>" '<img' "$out/card.html"
else
  echo "FAIL a Project with no image breaks the build"; fail=1
fi
cp "$out/projects.yaml" data/projects.yaml
refute "temporary Project is gone"                    'text-only-check' "$out/live/projects/index.html"
check  "recent posts heading"     'class="recent-posts"' "$out/drafts/index.html"
refute "no empty posts heading"   'class="recent-posts"' "$out/live/index.html"

# Drafts stay out of the live build.
[ ! -e "$out/live/posts/content-tools-sample" ] && echo "ok   draft excluded from live build" || { echo "FAIL draft excluded from live build"; fail=1; }

exit $fail
