#!/bin/bash

# Upload a single essay PDF to Zenodo
# Usage: ./zenodo-upload.sh <essay_abbrev> [--publish]
#
# Prerequisites:
#   Export ZENODO_TOKEN="your_token_here"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check arguments
if [[ -z "$1" ]]; then
    echo "Usage: $0 <essay_abbrev> [--publish]"
    echo "Example: $0 raw"
    exit 1
fi

ESSAY="$1"
PUBLISH=false
if [[ "$2" == "--publish" ]]; then
    PUBLISH=true
fi

PDF_FILE="$PROJECT_DIR/exports/pdf/${ESSAY}.pdf"
MD_FILE="$PROJECT_DIR/${ESSAY}.md"

ZENODO_URL="https://zenodo.org"
TOKEN="${ZENODO_TOKEN}"

# Check token
if [[ -z "$TOKEN" ]]; then
    echo "Error: ZENODO_TOKEN not set"
    exit 1
fi

# Check files exist
if [[ ! -f "$PDF_FILE" ]]; then
    echo "Error: PDF not found: $PDF_FILE"
    exit 1
fi

if [[ ! -f "$MD_FILE" ]]; then
    echo "Error: Markdown not found: $MD_FILE"
    exit 1
fi

# Extract metadata from markdown file using Python
METADATA=$(python3 << PYEOF
import re

with open("$MD_FILE", 'r') as f:
    content = f.read()

# Extract front matter
fm_match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
title = subtitle = description = ""
if fm_match:
    fm = fm_match.group(1)
    for line in fm.split('\n'):
        if line.startswith('title:'):
            title = line[6:].strip().strip('"').strip("'")
        elif line.startswith('subtitle:'):
            subtitle = line[9:].strip().strip('"').strip("'")
        elif line.startswith('description:'):
            description = line[12:].strip().strip('"').strip("'")

# Extract abstract (text between ## Abstract and the next ## or ---)
abstract_match = re.search(r'## Abstract[^\n]*\n+(.*?)(?=\n##|\n---|\Z)', content, re.DOTALL)
abstract = ""
if abstract_match:
    abstract = abstract_match.group(1).strip()
    # Clean up markdown formatting
    abstract = re.sub(r'\*\*([^*]+)\*\*', r'\1', abstract)  # Remove bold
    abstract = re.sub(r'\*([^*]+)\*', r'\1', abstract)  # Remove italic
    abstract = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', abstract)  # Remove links, keep text

# Output as shell-safe format
import json
print(json.dumps({
    "title": title,
    "subtitle": subtitle,
    "description": description,
    "abstract": abstract
}))
PYEOF
)

# Parse the JSON output
TITLE=$(echo "$METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
SUBTITLE=$(echo "$METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['subtitle'])")
DESCRIPTION=$(echo "$METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['description'])")
ABSTRACT=$(echo "$METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['abstract'])")

if [[ -n "$SUBTITLE" ]]; then
    FULL_TITLE="${TITLE}: ${SUBTITLE}"
else
    FULL_TITLE="$TITLE"
fi

echo ""
echo "Essay: $ESSAY"
echo "Title: $FULL_TITLE"
echo "Description: $DESCRIPTION"
echo "Abstract length: ${#ABSTRACT} chars"
echo "PDF: $PDF_FILE"
echo ""

# Step 1: Create a new deposition
echo "Creating new deposition..."
RESPONSE=$(curl -s -X POST "$ZENODO_URL/api/deposit/depositions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{}')

DEPOSITION_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
BUCKET_URL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['links']['bucket'])" 2>/dev/null)

if [[ -z "$DEPOSITION_ID" ]]; then
    echo "Error creating deposition:"
    echo "$RESPONSE"
    exit 1
fi

echo "Deposition ID: $DEPOSITION_ID"

# Step 2: Upload the PDF
echo "Uploading PDF..."
FILENAME=$(basename "$PDF_FILE")
curl -s -X PUT "$BUCKET_URL/$FILENAME" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$PDF_FILE" > /dev/null

echo "Upload complete."

# Step 3: Add metadata using Python for proper JSON encoding
echo "Adding metadata..."

python3 << PYEOF
import json
import requests
import sys

token = "$TOKEN"
deposition_id = "$DEPOSITION_ID"
zenodo_url = "$ZENODO_URL"

# Get metadata from environment/shell
metadata_json = '''$METADATA'''
meta = json.loads(metadata_json)

title = meta['title']
subtitle = meta['subtitle']
description = meta['description']
abstract = meta['abstract']

if subtitle:
    full_title = f"{title}: {subtitle}"
else:
    full_title = title

# Build description HTML - use abstract if available, otherwise description
if abstract:
    desc_html = f"""<p><strong>Abstract:</strong> {abstract}</p>
<p>Part of the <em>Return to Consciousness</em> research program—18 philosophical essays exploring consciousness-first metaphysics.</p>
<p>Full project: <a href="https://brunoton.github.io/return-to-consciousness/">https://brunoton.github.io/return-to-consciousness/</a></p>"""
else:
    desc_html = f"""<p>{description}</p>
<p>Part of the <em>Return to Consciousness</em> research program—18 philosophical essays exploring consciousness-first metaphysics.</p>
<p>Full project: <a href="https://brunoton.github.io/return-to-consciousness/">https://brunoton.github.io/return-to-consciousness/</a></p>"""

metadata = {
    "metadata": {
        "title": full_title,
        "upload_type": "publication",
        "publication_type": "preprint",
        "description": desc_html,
        "creators": [
            {
                "name": "Tonetto, Bruno",
                "affiliation": "Independent Researcher"
            }
        ],
        "keywords": [
            "consciousness",
            "philosophy of mind",
            "idealism",
            "analytic idealism",
            "metaphysics"
        ],
        "license": "cc-by-4.0",
        "access_right": "open",
        "language": "eng",
        "notes": "Co-authored with AI as a disciplined thinking instrument—not a replacement for judgment."
    }
}

response = requests.put(
    f"{zenodo_url}/api/deposit/depositions/{deposition_id}",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    json=metadata
)

if response.status_code != 200:
    print(f"Error: {response.status_code}")
    print(response.text)
    sys.exit(1)

print("Metadata added successfully.")
PYEOF

# Step 4: Publish if requested
if [[ "$PUBLISH" == "true" ]]; then
    echo "Publishing..."
    PUB_RESPONSE=$(curl -s -X POST "$ZENODO_URL/api/deposit/depositions/$DEPOSITION_ID/actions/publish" \
        -H "Authorization: Bearer $TOKEN")
    DOI=$(echo "$PUB_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('doi', 'unknown'))" 2>/dev/null)
    echo "Published! DOI: $DOI"
else
    echo ""
    echo "=========================================="
    echo "DEPOSITION CREATED (not yet published)"
    echo "=========================================="
    echo "Deposition ID: $DEPOSITION_ID"
    echo "Preview: $ZENODO_URL/deposit/$DEPOSITION_ID"
    echo ""
fi
