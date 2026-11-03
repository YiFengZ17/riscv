#!/usr/bin/env bash
# Rebuild lab/实验报告.pdf from lab/实验报告.md.
# Needs pandoc, Node with Playwright (Chromium), and a Chinese font such as WenQuanYi Zen Hei.
# Screenshots go in lab/images/ under the file names used in the report;
# a missing one shows up in the PDF as a dashed box with its file name.
set -euo pipefail
tools="$(cd "$(dirname "$0")" && pwd)"
lab="$(dirname "$tools")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$lab"
pandoc 实验报告.md -f markdown -t html5 --standalone --embed-resources \
    --metadata pagetitle="实验报告" --lua-filter "$tools/placeholder.lua" \
    --css "$tools/style.css" --no-highlight -o "$tmp/report.html"
node "$tools/to-pdf.js" "$tmp/report.html" "$lab/实验报告.pdf"
echo "wrote $lab/实验报告.pdf"
