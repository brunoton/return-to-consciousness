#!/bin/bash
# Compare current PDFs against stored checksums from last Zenodo upload.
# Usage:
#   ./scripts/check-pdfs.sh          # show which PDFs changed since last upload
#   ./scripts/check-pdfs.sh --save   # save current checksums (run after uploading)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PDF_DIR="$PROJECT_DIR/exports/pdf"
CHECKSUM_FILE="$PROJECT_DIR/exports/pdf-checksums"

ESSAYS=(rtc mmn amr bio wes ela eaa aam tcj apc bse tin tes raw eop cac cst ost)

if [[ "${1:-}" == "--save" ]]; then
    echo "Saving current PDF checksums..."
    > "$CHECKSUM_FILE"
    for essay in "${ESSAYS[@]}"; do
        pdf="$PDF_DIR/${essay}.pdf"
        if [[ -f "$pdf" ]]; then
            shasum -a 256 "$pdf" | awk '{print $1}' | tr -d '\n' >> "$CHECKSUM_FILE"
            echo "  ${essay}" >> "$CHECKSUM_FILE"
        fi
    done
    echo "Saved to .pdf-checksums"
    exit 0
fi

if [[ ! -f "$CHECKSUM_FILE" ]]; then
    echo "No .pdf-checksums file found. Run with --save after uploading to Zenodo."
    exit 1
fi

changed=()
missing=()
new=()

for essay in "${ESSAYS[@]}"; do
    pdf="$PDF_DIR/${essay}.pdf"
    if [[ ! -f "$pdf" ]]; then
        missing+=("$essay")
        continue
    fi

    current_hash=$(shasum -a 256 "$pdf" | awk '{print $1}')
    stored_hash=$(grep "  ${essay}$" "$CHECKSUM_FILE" | awk '{print $1}' || true)

    if [[ -z "$stored_hash" ]]; then
        new+=("$essay")
    elif [[ "$current_hash" != "$stored_hash" ]]; then
        changed+=("$essay")
    fi
done

if [[ ${#changed[@]} -eq 0 && ${#new[@]} -eq 0 && ${#missing[@]} -eq 0 ]]; then
    echo "All PDFs match last upload. Nothing to update."
    exit 0
fi

if [[ ${#changed[@]} -gt 0 ]]; then
    echo "CHANGED (need Zenodo update):"
    for e in "${changed[@]}"; do echo "  $e"; done
fi

if [[ ${#new[@]} -gt 0 ]]; then
    echo "NEW (no previous checksum):"
    for e in "${new[@]}"; do echo "  $e"; done
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "MISSING PDF:"
    for e in "${missing[@]}"; do echo "  $e"; done
fi
