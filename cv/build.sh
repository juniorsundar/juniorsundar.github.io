#!/usr/bin/env bash
# Build the CV PDF from data/cv.yaml + data/projects.yaml. Usage (inside `nix develop`):
#   cv/build.sh [out.pdf]                                   public CV, default static/cv.pdf
#   CV_PHONE="…" CV_ADDRESS="…" cv/build.sh cv-full.pdf     adds phone/address (never commit that file)
# For a Tailored CV (a chosen subset of projects), use the picker: `nix run .#pick`.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-static/cv.pdf}"
mkdir -p "$(dirname "$out")"  # static/ holds nothing tracked, so it may not exist in a fresh clone
typst compile --root . --input phone="${CV_PHONE:-}" --input address="${CV_ADDRESS:-}" cv/cv.typ "$out"
