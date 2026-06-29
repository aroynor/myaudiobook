#!/bin/bash
# Batch-converts every PDF in /books/pdf to EPUB in /books/epub
# using Calibre's CLI tool (ebook-convert), which ships inside the
# linuxserver/calibre image alongside the GUI.
#
# Run this via:
#   docker compose --profile convert run --rm calibre bash /scripts/convert-pdfs.sh

set -e

SRC="/books/pdf"
DST="/books/epub"

mkdir -p "$DST"

shopt -s nullglob
pdf_files=("$SRC"/*.pdf)

if [ ${#pdf_files[@]} -eq 0 ]; then
  echo "No PDF files found in $SRC"
  exit 0
fi

echo "Found ${#pdf_files[@]} PDF file(s). Starting conversion..."

for pdf in "${pdf_files[@]}"; do
  filename=$(basename "$pdf" .pdf)
  out="$DST/$filename.epub"

  if [ -f "$out" ]; then
    echo "Skipping (already converted): $filename"
    continue
  fi

  echo "Converting: $filename.pdf -> $filename.epub"
  ebook-convert "$pdf" "$out" \
    --enable-heuristics \
    --output-profile=generic_eink

  echo "Done: $filename.epub"
done

echo "All conversions finished. Output in $DST"
