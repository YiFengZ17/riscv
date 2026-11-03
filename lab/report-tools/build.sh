#!/usr/bin/env bash
# Rebuild the report: 实验报告.md -> 实验报告.tex -> 实验报告.pdf (XeLaTeX).
# Needs pandoc and TeX Live with XeLaTeX and ctex
# (Ubuntu: texlive-xetex texlive-lang-chinese texlive-latex-extra texlive-fonts-recommended latexmk).
# Edit 实验报告.md, not the .tex file: the .tex is regenerated every time.
# Screenshots go in lab/images/ under the file names used in the report;
# a missing one shows up in the PDF as a red box with its file name.
set -euo pipefail
tools="$(cd "$(dirname "$0")" && pwd)"
lab="$(dirname "$tools")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$lab"
pandoc 实验报告.md -f markdown -t latex --standalone --shift-heading-level-by=-1 \
    --template "$tools/template.tex" --lua-filter "$tools/latex-filter.lua" \
    --highlight-style tango -o 实验报告.tex
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir="$tmp" -jobname=report 实验报告.tex > "$tmp/latexmk.log" 2>&1 \
    || { tail -40 "$tmp/report.log" 2>/dev/null || tail -40 "$tmp/latexmk.log"; exit 1; }
cp "$tmp/report.pdf" 实验报告.pdf
grep -E "Missing character|Overfull \\\\hbox \([0-9]{2,}" "$tmp/report.log" | sort | uniq -c | head -20 || true
echo "wrote $lab/实验报告.tex and $lab/实验报告.pdf"
