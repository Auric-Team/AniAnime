#!/bin/bash

# Megacloud Proxy Deployment Script

echo "=== Megacloud Proxy Deployment ==="
echo ""

cd "$(dirname "$0")/hono-proxy"

echo "Installing dependencies..."
npm install

echo ""
echo "Deploying to Vercel..."
echo "Make sure you're logged in to Vercel (run: vercel login)"
echo ""

vercel --prod

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Copy the deployed URL (e.g., https://megacloud-proxy-xxxxx.vercel.app)"
echo "2. Update ApiService.proxyBaseUrl in lib/services/api_service.dart"
echo "3. Run flutter pub get and build your app"
