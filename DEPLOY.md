# Megacloud Stream Proxy Deployment

## Prerequisites
- Node.js 18+ installed
- Vercel CLI installed: `npm i -g vercel`
- Vercel account logged in: `vercel login`

## Quick Deploy

Run the deployment script:
```bash
./deploy-proxy.sh
```

Or manually:
```bash
cd hono-proxy
npm install
vercel --prod
```

## After Deployment

1. Copy your Vercel URL (e.g., `https://megacloud-proxy-xxxxx.vercel.app`)
2. Open `lib/services/api_service.dart`
3. Update this line:
   ```dart
   static const String proxyBaseUrl = 'https://your-vercel-url.vercel.app';
   ```
4. Run `flutter pub get`
5. Build and test your app

## Testing

Test the proxy:
```bash
curl https://your-vercel-url.vercel.app/health
```

Test with a stream URL:
```bash
curl "https://your-vercel-url.vercel.app/proxy?url=https%3A%2F%2Fexample.com%2Fstream.m3u8"
```
