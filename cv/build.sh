#!/usr/bin/env bash
# Build the CV PDF from data/cv.yaml. Usage (inside `nix develop`):
#   cv/build.sh [out.pdf]                                   public CV, default static/cv.pdf
#   CV_PHONE="…" CV_ADDRESS="…" cv/build.sh cv-full.pdf     adds phone/address (never commit that file)
set -euo pipefail
cd "$(dirname "$0")/.."
typst compile --root . --input phone="${CV_PHONE:-}" --input address="${CV_ADDRESS:-}" cv/cv.typ "${1:-static/cv.pdf}"
