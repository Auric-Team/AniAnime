import { Hono } from 'hono';
import { handle } from '@hono/node-server/vercel';

const app = new Hono().basePath('/');

// CORS Middleware
app.use('*', async (c, next) => {
  c.header('Access-Control-Allow-Origin', '*');
  c.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  c.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
  c.header('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  
  if (c.req.method === 'OPTIONS') {
    return c.body(null, 204);
  }
  
  await next();
});

/**
 * Main proxy endpoint for m3u8 manifests and video segments
 */
app.get('/proxy', async (c) => {
  const targetUrl = c.req.query('url');
  
  if (!targetUrl) {
    return c.json({ error: 'Missing URL parameter' }, 400);
  }

  try {
    // Decode URL
    let decodedUrl = targetUrl;
    try {
      decodedUrl = decodeURIComponent(targetUrl);
      if (decodedUrl.includes('%')) {
        decodedUrl = decodeURIComponent(decodedUrl);
      }
    } catch {
      decodedUrl = targetUrl;
    }

    // Validate URL
    try {
      new URL(decodedUrl);
    } catch {
      return c.json({ error: 'Invalid URL format' }, 400);
    }

    // Headers for upstream request (spoof Megacloud origin)
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': 'https://megacloud.blog',
      'Referer': 'https://megacloud.blog/',
    };

    // Handle range requests
    const rangeHeader = c.req.header('range');
    if (rangeHeader) {
      headers['Range'] = rangeHeader;
    }

    // Fetch from upstream
    const response = await fetch(decodedUrl, {
      method: 'GET',
      headers,
      redirect: 'follow',
    });

    if (!response.ok && response.status !== 206) {
      return c.json({ 
        error: 'Upstream request failed', 
        status: response.status,
        url: decodedUrl 
      }, 502);
    }

    // Get content type
    const contentType = response.headers.get('content-type') || '';
    
    // Check if it's m3u8
    const isM3U8 = decodedUrl.includes('.m3u8') || 
                   contentType.includes('mpegurl') ||
                   contentType.includes('m3u8');
    
    // Get response body
    const body = await response.arrayBuffer();

    if (isM3U8) {
      // Rewrite m3u8 manifest
      const text = new TextDecoder().decode(body);
      const baseUrl = decodedUrl.substring(0, decodedUrl.lastIndexOf('/') + 1);
      const proxyBase = `${new URL(c.req.url).origin}/proxy?url=`;
      
      const rewrittenManifest = rewriteM3U8(text, baseUrl, proxyBase);
      
      c.header('Content-Type', 'application/vnd.apple.mpegurl');
      c.header('Cache-Control', 'no-cache');
      
      return c.body(rewrittenManifest);
    } else {
      // For segments - preserve original content type or use video/MP2T
      const finalContentType = contentType.includes('image') || contentType.includes('html') 
        ? 'video/MP2T'  // Disguised video segments
        : (contentType || 'video/MP2T');
      
      c.header('Content-Type', finalContentType);
      
      const cacheControl = response.headers.get('cache-control');
      if (cacheControl) c.header('Cache-Control', cacheControl);
      
      const contentLength = response.headers.get('content-length');
      if (contentLength) c.header('Content-Length', contentLength);
      
      if (response.status === 206) {
        c.status(206);
        const contentRange = response.headers.get('content-range');
        if (contentRange) c.header('Content-Range', contentRange);
      }
      
      return c.body(body);
    }
  } catch (error) {
    console.error('Proxy error:', error);
    return c.json({ 
      error: 'Proxy request failed',
      message: error instanceof Error ? error.message : 'Unknown error'
    }, 500);
  }
});

/**
 * Rewrite m3u8 manifest - replace segment URLs with proxied versions
 */
function rewriteM3U8(manifest: string, baseUrl: string, proxyBase: string): string {
  const lines = manifest.split('\n');
  const rewritten: string[] = [];
  
  for (const line of lines) {
    const trimmedLine = line.trim();
    
    // Handle tags
    if (trimmedLine.startsWith('#')) {
      if (trimmedLine.startsWith('#EXT-X-KEY')) {
        rewritten.push(rewriteKeyUri(trimmedLine, baseUrl, proxyBase));
      } else {
        rewritten.push(line);
      }
      continue;
    }
    
    // Skip empty lines
    if (!trimmedLine) {
      rewritten.push(line);
      continue;
    }
    
    // Rewrite segment/sub-playlist URLs (including disguised ones)
    if (isSegmentUrl(trimmedLine)) {
      const absoluteUrl = trimmedLine.startsWith('http') 
        ? trimmedLine 
        : new URL(trimmedLine, baseUrl).href;
      const proxiedUrl = proxyBase + encodeURIComponent(absoluteUrl);
      rewritten.push(proxiedUrl);
    } else {
      rewritten.push(line);
    }
  }
  
  return rewritten.join('\n');
}

/**
 * Check if URL is a segment or playlist
 */
function isSegmentUrl(url: string): boolean {
  // Include disguised extensions
  const videoExtensions = ['.ts', '.m3u8', '.jpg', '.html', '.css', '.js', '.png', '.gif'];
  return videoExtensions.some(ext => url.toLowerCase().includes(ext)) ||
         url.includes('seg-') ||
         url.includes('iframe');
}

/**
 * Rewrite AES key URI in EXT-X-KEY tag
 */
function rewriteKeyUri(tag: string, baseUrl: string, proxyBase: string): string {
  const uriMatch = tag.match(/URI="([^"]+)"/);
  if (!uriMatch) return tag;
  
  const originalUri = uriMatch[1];
  const absoluteUri = originalUri.startsWith('http') 
    ? originalUri 
    : new URL(originalUri, baseUrl).href;
  
  const proxiedUri = proxyBase + encodeURIComponent(absoluteUri);
  return tag.replace(`URI="${originalUri}"`, `URI="${proxiedUri}"`);
}

// Health check
app.get('/health', (c) => {
  return c.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    version: '1.1.0'
  });
});

// Root endpoint
app.get('/', (c) => {
  return c.json({
    name: 'Megacloud Stream Proxy',
    version: '1.1.0',
    description: 'HLS Stream Proxy with m3u8 rewriting for Megacloud',
    features: [
      'M3U8 manifest rewriting',
      'Segment proxying with spoofed headers',
      'Handles disguised video segments (.jpg, .html, etc.)'
    ],
    endpoints: {
      '/proxy?url=<stream_url>': 'Proxy streams with Referer spoofing',
      '/health': 'Health check'
    }
  });
});

// Export for Vercel
export const GET = handle(app);
export const POST = handle(app);
export const OPTIONS = handle(app);

export default app;
