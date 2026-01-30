#!/usr/bin/env python3
"""Concatenate all essay PDFs into a single complete PDF.

Usage:
    python3 scripts/generate-complete-pdf.py
    python3 scripts/generate-complete-pdf.py --output path/to/output.pdf

Order follows index.md section structure:
  Core Framework → Structural Extensions → Epistemic Gatekeepers →
  Applied Domains → Boundary Tests → Reference Material
"""

import argparse
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
PDF_DIR = PROJECT_DIR / "exports" / "pdf"
DEFAULT_OUTPUT = PROJECT_DIR / "_draft" / "rtc-complete.pdf"

# Order follows index.md sections
ESSAYS = [
    # Core Framework
    "rtc",
    # Structural Extensions
    "apc", "bse", "ost", "bio",
    # Epistemic Gatekeepers
    "mmn", "eop", "amr", "wes", "eaa", "raw",
    # Applied Domains
    "ela", "tin", "aam", "cst",
    # Boundary Tests
    "tcj", "tes",
    # Reference Material
    "cac",
]


def main():
    parser = argparse.ArgumentParser(description="Concatenate all essay PDFs")
    parser.add_argument("--output", "-o", type=Path, default=DEFAULT_OUTPUT,
                        help=f"Output path (default: {DEFAULT_OUTPUT})")
    args = parser.parse_args()

    # Verify all PDFs exist
    pdf_files = []
    missing = []
    for essay in ESSAYS:
        pdf = PDF_DIR / f"{essay}.pdf"
        if not pdf.exists():
            missing.append(essay)
        else:
            pdf_files.append(str(pdf))

    if missing:
        print(f"Error: Missing PDFs: {', '.join(missing)}")
        print("Run ./scripts/generate-pdfs.sh first")
        sys.exit(1)

    # Ensure output directory exists
    args.output.parent.mkdir(parents=True, exist_ok=True)

    # Concatenate using pdfunite (poppler-utils)
    cmd = ["pdfunite"] + pdf_files + [str(args.output)]
    try:
        subprocess.run(cmd, check=True)
    except FileNotFoundError:
        print("Error: pdfunite not found. Install poppler:")
        print("  brew install poppler")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error: pdfunite failed with exit code {e.returncode}")
        sys.exit(1)

    size_mb = args.output.stat().st_size / (1024 * 1024)
    print(f"Created {args.output} ({size_mb:.1f} MB, {len(ESSAYS)} essays)")


if __name__ == "__main__":
    main()
