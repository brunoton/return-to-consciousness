#!/bin/bash

# Update the PDF on an existing Zenodo record (creates a new version)
# Usage: ./zenodo-update-pdf.sh <essay_abbrev> [--publish]
#
# Prerequisites:
#   Export ZENODO_TOKEN="your_token_here"
#
# What it does:
#   1. Looks up the DOI from index.md to find the Zenodo record ID
#   2. Creates a new version of that record
#   3. Deletes the old PDF and uploads the new one
#   4. Optionally publishes the new version

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check arguments
if [[ -z "$1" ]]; then
    echo "Usage: $0 <essay_abbrev> [--publish]"
    echo "Example: $0 raw"
    echo "Example: $0 raw --publish"
    exit 1
fi

ESSAY="$1"
PUBLISH=false
if [[ "$2" == "--publish" ]]; then
    PUBLISH=true
fi

PDF_FILE="$PROJECT_DIR/exports/pdf/${ESSAY}.pdf"
INDEX_FILE="$PROJECT_DIR/index.md"

ZENODO_URL="https://zenodo.org"
TOKEN="${ZENODO_TOKEN}"

# Check token
if [[ -z "$TOKEN" ]]; then
    echo "Error: ZENODO_TOKEN not set"
    echo "Export it first: export ZENODO_TOKEN='your_token'"
    exit 1
fi

# Check PDF exists
if [[ ! -f "$PDF_FILE" ]]; then
    echo "Error: PDF not found: $PDF_FILE"
    echo "Run ./scripts/generate-pdfs.sh first"
    exit 1
fi

# Extract DOI from index.md using Python (macOS-compatible)
read -r DOI RECORD_ID <<< $(python3 -c "
import re
with open('$INDEX_FILE') as f:
    content = f.read()
# Find DOI near the essay abbreviation
pattern = r'/${ESSAY}[)\s].*?https://doi\.org/10\.5281/zenodo\.(\d+)'
match = re.search(pattern, content, re.DOTALL)
if not match:
    # Try broader search
    for line in content.split('\n'):
        if '${ESSAY}' in line:
            m = re.search(r'https://doi\.org/10\.5281/zenodo\.(\d+)', line)
            if m:
                print(f'https://doi.org/10.5281/zenodo.{m.group(1)} {m.group(1)}')
                exit()
    print('')
else:
    print(f'https://doi.org/10.5281/zenodo.{match.group(1)} {match.group(1)}')
")

if [[ -z "$DOI" ]]; then
    echo "Error: Could not find DOI for essay '$ESSAY' in index.md"
    exit 1
fi

echo ""
echo "Essay: $ESSAY"
echo "DOI: $DOI"
echo "Record ID (from index.md): $RECORD_ID"
echo "PDF: $PDF_FILE"

# Resolve concept DOI to latest version record ID (concept IDs redirect)
RESOLVED_ID=$(curl -s -L "$ZENODO_URL/api/records/$RECORD_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
if [[ -n "$RESOLVED_ID" && "$RESOLVED_ID" != "$RECORD_ID" ]]; then
    echo "Resolved to latest version record ID: $RESOLVED_ID"
    RECORD_ID="$RESOLVED_ID"
fi
echo ""

# Step 1: Create a new version of the existing record
echo "Creating new version..."
NEWVER_RESPONSE=$(curl -s -X POST "$ZENODO_URL/api/deposit/depositions/$RECORD_ID/actions/newversion" \
    -H "Authorization: Bearer $TOKEN")

# The response contains a link to the new draft version
DRAFT_URL=$(echo "$NEWVER_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'links' in data and 'latest_draft' in data['links']:
    print(data['links']['latest_draft'])
else:
    print('ERROR')
    print(json.dumps(data, indent=2), file=sys.stderr)
" 2>&1)

if [[ "$DRAFT_URL" == "ERROR"* ]]; then
    echo "Error creating new version:"
    echo "$NEWVER_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$NEWVER_RESPONSE"
    exit 1
fi

echo "Draft URL: $DRAFT_URL"

# Step 2: Get the draft deposition details (need bucket URL and old file IDs)
DRAFT_RESPONSE=$(curl -s -X GET "$DRAFT_URL" \
    -H "Authorization: Bearer $TOKEN")

DRAFT_ID=$(echo "$DRAFT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
BUCKET_URL=$(echo "$DRAFT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['links']['bucket'])")

echo "Draft deposition ID: $DRAFT_ID"

# Step 3: Delete old file(s)
echo "Removing old file(s)..."
OLD_FILES=$(echo "$DRAFT_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('files', []):
    print(f['id'])
")

for FILE_ID in $OLD_FILES; do
    curl -s -X DELETE "$ZENODO_URL/api/deposit/depositions/$DRAFT_ID/files/$FILE_ID" \
        -H "Authorization: Bearer $TOKEN" > /dev/null
    echo "  Deleted file: $FILE_ID"
done

# Step 4: Upload new PDF
echo "Uploading new PDF..."
FILENAME=$(basename "$PDF_FILE")
curl -s -X PUT "$BUCKET_URL/$FILENAME" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$PDF_FILE" > /dev/null

echo "Upload complete."

# Step 5: Publish if requested
if [[ "$PUBLISH" == "true" ]]; then
    # Set publication_date (required for new versions)
    echo "Setting publication date..."
    CURRENT_META=$(curl -s "$ZENODO_URL/api/deposit/depositions/$DRAFT_ID" \
        -H "Authorization: Bearer $TOKEN")
    UPDATED_META=$(echo "$CURRENT_META" | python3 -c "
import sys, json, datetime
data = json.load(sys.stdin)
meta = data.get('metadata', {})
meta['publication_date'] = datetime.date.today().isoformat()
print(json.dumps({'metadata': meta}))
")
    curl -s -X PUT "$ZENODO_URL/api/deposit/depositions/$DRAFT_ID" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$UPDATED_META" > /dev/null

    echo "Publishing new version..."
    PUB_RESPONSE=$(curl -s -X POST "$ZENODO_URL/api/deposit/depositions/$DRAFT_ID/actions/publish" \
        -H "Authorization: Bearer $TOKEN")
    NEW_DOI=$(echo "$PUB_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('doi', 'unknown'))" 2>/dev/null)
    echo "Published! DOI: $NEW_DOI"
else
    echo ""
    echo "=========================================="
    echo "NEW VERSION CREATED (not yet published)"
    echo "=========================================="
    echo "Draft ID: $DRAFT_ID"
    echo "Preview: $ZENODO_URL/deposit/$DRAFT_ID"
    echo ""
    echo "To publish: $0 $ESSAY --publish"
    echo "(or publish manually from the Zenodo web UI)"
    echo ""
fi
