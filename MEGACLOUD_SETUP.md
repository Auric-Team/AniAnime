# Megacloud Stream Proxy + Decryption

This project implements a complete cryptographic pipeline for extracting and playing Megacloud-protected streams directly.

## Architecture

### 1. Dart Megacloud Service (`lib/services/megacloud_service.dart`)
- Implements AES-256-CBC decryption
- OpenSSL EVP_BytesToKey key derivation
- Client key extraction from embed pages
- Stream URL proxy rewriting

### 2. Vercel Hono Proxy (`hono-proxy/`)
- Serverless proxy deployed on Vercel
- Real-time m3u8 manifest rewriting
- Proxies video segments with proper Referer/Origin headers
- CORS handling for Flutter WebView

### 3. API Service (`lib/services/api_service.dart`)
- Direct Megacloud source extraction
- Falls back to Tatakai API if extraction fails
- Automatic stream URL proxying

## Deployment

### Deploy Proxy to Vercel

```bash
cd hono-proxy
npm install
vercel --prod
```

After deployment, update `ApiService.proxyBaseUrl` in `lib/services/api_service.dart` with your Vercel URL.

## How It Works

1. **Extract Episode ID**: Query HiAnime's `/ajax/v2/episode/servers` API
2. **Fetch Embed Page**: Get the Megacloud embed HTML to extract client key (_k)
3. **Get Encrypted Sources**: Call `/ajax/player` with data-id and client key
4. **Decrypt**: Use the V3 secret key with AES-256-CBC decryption
5. **Proxy Streams**: Rewrite m3u8 manifest and proxy all segments through Vercel
6. **Play**: Load proxied stream URL in HLS.js player

## Key Components

### Decryption Key
The V3 secret key is reverse-engineered from `embed-1.min.js`:
```
7MeMRClEneUmFoHRO3u3ypzAZXlVgNtBE2pKDw==
```

### Headers for CDN Access
```
Referer: https://megacloud.blog/
Origin: https://megacloud.blog
```

### Proxy URL Format
```
https://your-proxy.vercel.app/proxy?url=<encoded_stream_url>
```

## Security Notes

- The secret key is hardcoded as it is publicly available in the player JS
- Client key (_k) is session-specific and extracted dynamically
- All stream requests are proxied to bypass CORS and Referer checks
