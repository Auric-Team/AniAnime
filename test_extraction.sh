#!/bin/bash

# Megacloud Full Extraction Test Script
# This tests the complete pipeline: data-id -> client key -> getSources -> decrypt -> stream

echo "=== Megacloud Full Extraction Test ==="
echo ""

# Use proxy for all requests
PROXY="http://205.209.118.30:3138"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"

echo "Step 1: Getting episode servers list..."
SERVERS_HTML=$(curl -s -x "$PROXY" -A "$USER_AGENT" -H "Referer: https://hianime.to/" \
  "https://hianime.to/ajax/v2/episode/servers?episodeId=102662" 2>&1)

# Extract data-id for Megacloud (server-id="1")
DATA_ID=$(echo "$SERVERS_HTML" | grep -o 'data-server-id="1"[^>]*data-id="[0-9]*"' | grep -o 'data-id="[0-9]*"' | head -1 | cut -d'"' -f2)

echo "Found data-id: $DATA_ID"
echo ""

if [ -z "$DATA_ID" ]; then
    echo "ERROR: Could not find data-id"
    exit 1
fi

echo "Step 2: Fetching embed page to extract client key..."
EMBED_HTML=$(curl -s -x "$PROXY" -A "$USER_AGENT" -H "Referer: https://hianime.to/" \
  "https://megacloud.blog/embed-2/v3/e-1/$DATA_ID" 2>&1)

# Check if embed page loaded
if echo "$EMBED_HTML" | grep -q "File not found"; then
    echo "ERROR: Embed page returned 404 - data-id may be invalid"
    echo "Trying alternative data-id..."
    # Try other server IDs
    DATA_ID=$(echo "$SERVERS_HTML" | grep -o 'data-id="[0-9]*"' | head -2 | tail -1 | cut -d'"' -f2)
    echo "Trying data-id: $DATA_ID"
    
    EMBED_HTML=$(curl -s -x "$PROXY" -A "$USER_AGENT" -H "Referer: https://hianime.to/" \
      "https://megacloud.blog/embed-2/v3/e-1/$DATA_ID" 2>&1)
fi

# Extract client key (_k) from embed page
# Try multiple patterns
CLIENT_KEY=$(echo "$EMBED_HTML" | grep -oP 'window\._lk_db\s*=\s*\{[^}]*"_k"\s*:\s*"[^"]*"' | grep -oP '"_k"\s*:\s*"\K[^"]*')

if [ -z "$CLIENT_KEY" ]; then
    CLIENT_KEY=$(echo "$EMBED_HTML" | grep -o 'k=[^&"]*' | head -1 | cut -d'=' -f2)
fi

if [ -z "$CLIENT_KEY" ]; then
    echo "WARNING: Could not extract client key, trying without..."
    CLIENT_KEY=""
else
    echo "Found client key: ${CLIENT_KEY:0:20}..."
fi

echo ""
echo "Step 3: Calling getSources API..."

if [ -n "$CLIENT_KEY" ]; then
    SOURCES_URL="https://megacloud.blog/embed-2/v3/e-1/getSources?id=$DATA_ID&_k=$CLIENT_KEY"
else
    SOURCES_URL="https://megacloud.blog/embed-2/v3/e-1/getSources?id=$DATA_ID"
fi

echo "URL: $SOURCES_URL"

SOURCES_RESPONSE=$(curl -s -x "$PROXY" -A "$USER_AGENT" \
  -H "Referer: https://megacloud.blog/embed-2/v3/e-1/$DATA_ID?k=1" \
  "$SOURCES_URL" 2>&1)

echo ""
echo "Step 4: Processing response..."

# Check if response is valid JSON
if echo "$SOURCES_RESPONSE" | grep -q "Invalid client key"; then
    echo "ERROR: Invalid client key"
    echo "Response: $SOURCES_RESPONSE"
    exit 1
fi

if echo "$SOURCES_RESPONSE" | grep -q '"sources"'; then
    echo "SUCCESS: Got sources response"
    echo ""
    
    # Check if encrypted
    if echo "$SOURCES_RESPONSE" | grep -q '"encrypted":true'; then
        echo "Response is encrypted - decryption needed"
        # Extract encrypted data
        ENCRYPTED=$(echo "$SOURCES_RESPONSE" | grep -o '"file":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "Encrypted data: ${ENCRYPTED:0:50}..."
        echo ""
        echo "Decrypting with V3 key..."
        # Decryption would happen here with OpenSSL
        echo "(Decryption requires OpenSSL with AES-256-CBC support)"
    else
        echo "Response is NOT encrypted - extracting direct URL"
        STREAM_URL=$(echo "$SOURCES_RESPONSE" | grep -o '"file":"[^"]*m3u8[^"]*"' | head -1 | cut -d'"' -f4)
        echo ""
        echo "=== FINAL STREAM URL ==="
        echo "$STREAM_URL"
        echo ""
        
        # Test the stream
        echo "Step 5: Testing stream..."
        STREAM_TEST=$(curl -s -I -H "Referer: https://megacloud.blog/" "$STREAM_URL" 2>&1 | head -1)
        echo "Response: $STREAM_TEST"
    fi
else
    echo "ERROR: No sources in response"
    echo "Response: $SOURCES_RESPONSE"
    exit 1
fi
