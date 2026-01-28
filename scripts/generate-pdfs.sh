#!/bin/bash

# Generate PDFs from essay markdown files using pandoc
# Requires: pandoc, pdflatex (basictex or mactex)
#
# Usage: ./generate-pdfs.sh [--force]
#   --force  Regenerate all PDFs regardless of timestamps

set -e

FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Ensure LaTeX is in PATH
eval "$(/usr/libexec/path_helper)" 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/exports/pdf"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Essays to convert (root level .md files that are actual essays)
ESSAYS=(
    "rtc" 
    "mmn" 
    "amr" 
    "bio" 
    "wes" 
    "ela" 
    "eaa" 
    "aam" 
    "tcj" 
    "apc" 
    "bse" 
    "tin" 
    "tes" 
    "raw" 
    "eop" 
    "cac" 
    "cst" 
    "ost" 
)

# Base URL for the published site
SITE_URL="https://brunoton.github.io/return-to-consciousness"

# Function to extract front matter field
get_front_matter() {
    local input="$1"
    local field="$2"
    # Extract value from YAML front matter
    awk -v field="$field" '
        BEGIN { in_front=0; found=0 }
        /^---$/ { if (!in_front) { in_front=1; next } else { exit } }
        in_front && $0 ~ "^"field":" {
            sub("^"field":[ ]*", "")
            gsub(/^["'\''"]|["'\''"]$/, "")  # Remove quotes
            print
            found=1
            exit
        }
    ' "$input"
}

# Function to strip Jekyll front matter and clean up markdown
process_markdown() {
    local input="$1"
    # Remove Jekyll front matter (first --- block only)
    # Remove {#anchor} tags from headings
    # Remove image lines (![...](...)  )
    # Convert {{ site.baseurl }} links to full URLs
    awk 'BEGIN{f=0;d=0}/^---$/{if(!d){if(f){d=1;next}else{f=1;next}}}f==0||d==1{print}' "$input" \
        | sed -E 's/\{#[^}]+\}//g; /^!\[.*\]\(.*\)$/d; /^---$/d; /^\*[0-9]+ pages .* min read .* \[PDF\]/d' \
        | sed "s|{{ site.baseurl }}|$SITE_URL|g"
}

echo "Generating PDFs..."
echo "Output directory: $OUTPUT_DIR"
echo ""

for essay in "${ESSAYS[@]}"; do
    input_file="$PROJECT_DIR/$essay.md"
    output_file="$OUTPUT_DIR/$essay.pdf"

    if [[ ! -f "$input_file" ]]; then
        echo "⚠ Skipping $essay.md (not found)"
        continue
    fi

    # Skip if PDF is newer than source (unless --force)
    if [[ "$FORCE" == "false" && -f "$output_file" && "$output_file" -nt "$input_file" ]]; then
        echo "⏭ Skipping $essay.md (PDF is up to date)"
        continue
    fi

    echo "Converting $essay.md..."

    # Extract title and subtitle from front matter
    title=$(get_front_matter "$input_file" "title")
    subtitle=$(get_front_matter "$input_file" "subtitle")

    # Build pandoc command with metadata
    pandoc_args=(
        --from markdown+pipe_tables
        --to pdf
        --pdf-engine=xelatex
        -V papersize=a4
        -V geometry:margin=1in
        -V fontsize=12pt
        -V documentclass=article
        -V colorlinks=true
        -V linkcolor=blue
        -V urlcolor=blue
        -V "mainfont=Times New Roman"
    )

    # Add title metadata
    if [[ -n "$title" ]]; then
        pandoc_args+=(-M "title=$title")
    fi

    # Add subtitle if present
    if [[ -n "$subtitle" ]]; then
        pandoc_args+=(-M "subtitle=$subtitle")
    fi

    # Process markdown and convert to PDF
    # Using xelatex for better Unicode support
    process_markdown "$input_file" | pandoc "${pandoc_args[@]}" \
        -H <(echo '\usepackage{booktabs}
\usepackage[table]{xcolor}
\rowcolors{2}{gray!15}{white}') \
        -o "$output_file"

    echo "✓ Created $output_file"
done

echo ""
echo "Done! PDFs saved to $OUTPUT_DIR"
