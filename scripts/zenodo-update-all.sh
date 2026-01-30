#!/bin/bash
# Update all essay PDFs on Zenodo (creates new versions for each)
# Usage:
#   ./scripts/zenodo-update-all.sh              # dry run (no --publish)
#   ./scripts/zenodo-update-all.sh --publish    # publish all updates
#
# Prerequisites: export ZENODO_TOKEN="your_token_here"
# Runs generate-pdfs.sh --force first, then updates each essay on Zenodo,
# then saves checksums.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PUBLISH_FLAG=""
if [[ "${1:-}" == "--publish" ]]; then
    PUBLISH_FLAG="--publish"
fi

ESSAYS=(rtc mmn amr bio wes ela eaa aam tcj apc bse tin tes raw eop cac cst ost)

echo "=== Regenerating all PDFs ==="
"$SCRIPT_DIR/generate-pdfs.sh" --force

echo ""
echo "=== Updating Zenodo records ==="
failed=()
for essay in "${ESSAYS[@]}"; do
    echo ""
    echo "--- $essay ---"
    if "$SCRIPT_DIR/zenodo-update-pdf.sh" "$essay" $PUBLISH_FLAG; then
        echo "OK: $essay"
    else
        echo "FAILED: $essay"
        failed+=("$essay")
    fi
done

echo ""
echo "=== Saving checksums ==="
"$SCRIPT_DIR/check-pdfs.sh" --save

echo ""
if [[ ${#failed[@]} -eq 0 ]]; then
    echo "All essays updated successfully."
else
    echo "FAILED essays:"
    for e in "${failed[@]}"; do echo "  $e"; done
    exit 1
fi
