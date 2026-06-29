#!/bin/bash
# Helper: times how long abogen-web takes to process a single short
# text file, so you can estimate total processing time before queuing
# a full book.
#
# Usage:
#   1. Put a short sample text (one chapter, ~3000-5000 words) at:
#        ./data/epubs/_benchmark_sample.txt
#   2. Run this script from the project root:
#        bash scripts/benchmark-chapter.sh
#
# It just prints instructions + timing guidance; actual conversion
# still happens through the abogen-web UI at http://<server-ip>:8808,
# since abogen does not expose a scriptable CLI job API.

SAMPLE="./data/epubs/_benchmark_sample.txt"

if [ ! -f "$SAMPLE" ]; then
  echo "Sample file not found at $SAMPLE"
  echo "Create one first: take a single chapter from one of your books"
  echo "(roughly 3,000-5,000 words) and save it as a plain .txt file there."
  exit 1
fi

word_count=$(wc -w < "$SAMPLE")
echo "Sample file: $SAMPLE"
echo "Word count: $word_count"
echo ""
echo "Next steps:"
echo "1. Open http://<your-server-ip>:8808 in a browser"
echo "2. Upload _benchmark_sample.txt, pick your voice, and click 'Create job'"
echo "3. Note the start time and finish time of the job in the dashboard"
echo ""
echo "Once you have the elapsed time (in seconds), estimate the full book:"
echo "  full_book_words = (pages_in_book * ~300)"
echo "  scale_factor = full_book_words / $word_count"
echo "  estimated_seconds = elapsed_seconds_for_sample * scale_factor"
echo ""
echo "Example: if your $word_count-word sample took 90 seconds, and your"
echo "full book is 150,000 words, scale_factor = 150000 / $word_count"
echo "estimated_seconds = 90 * scale_factor"
