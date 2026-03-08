// Cloudflare Worker for Megacloud Stream Proxy
// Deploy to: https://workers.cloudflare.com/

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Range',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        version: '1.0.0'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Proxy endpoint
    if (url.pathname === '/proxy') {
      const targetUrl = url.searchParams.get('url');
      
      if (!targetUrl) {
        return new Response(JSON.stringify({ error: 'Missing URL' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      try {
        // Decode URL
        let decodedUrl;
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
          return new Response(JSON.stringify({ error: 'Invalid URL' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Prepare headers for upstream
        const upstreamHeaders = {
          'User-Agent': request.headers.get('user-agent') || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': request.headers.get('accept') || '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Origin': 'https://megacloud.blog',
          'Referer': 'https://megacloud.blog/',
        };

        // Pass through range header
        const range = request.headers.get('range');
        if (range) upstreamHeaders['Range'] = range;

        // Fetch from upstream
        const response = await fetch(decodedUrl, {
          method: 'GET',
          headers: upstreamHeaders,
          redirect: 'follow',
        });

        if (!response.ok && response.status !== 206) {
          return new Response(JSON.stringify({ 
            error: 'Upstream failed', 
            status: response.status 
          }), {
            status: 502,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        // Determine content type
        const contentType = response.headers.get('content-type') || '';
        const isM3U8 = decodedUrl.includes('.m3u8') || contentType.includes('mpegurl');

        // Prepare response headers
        const responseHeaders = { ...corsHeaders };
        
        if (isM3U8) {
          // Rewrite m3u8 manifest
          const text = await response.text();
          const baseUrl = decodedUrl.substring(0, decodedUrl.lastIndexOf('/') + 1);
          const proxyBase = `${url.origin}/proxy?url=`;
          
          const rewritten = rewriteM3U8(text, baseUrl, proxyBase);
          
          responseHeaders['Content-Type'] = 'application/vnd.apple.mpegurl';
          responseHeaders['Cache-Control'] = 'no-cache';
          
          return new Response(rewritten, { headers: responseHeaders });
        } else {
          // For segments - fix content type for disguised segments
          let finalContentType = contentType;
          if (contentType.includes('image') || contentType.includes('html') || !contentType) {
            finalContentType = 'video/MP2T';
          }
          
          responseHeaders['Content-Type'] = finalContentType;
          
          const contentLength = response.headers.get('content-length');
          if (contentLength) responseHeaders['Content-Length'] = contentLength;
          
          const cacheControl = response.headers.get('cache-control');
          if (cacheControl) responseHeaders['Cache-Control'] = cacheControl;
          
          if (response.status === 206) {
            responseHeaders['Content-Range'] = response.headers.get('content-range');
            return new Response(response.body, { 
              status: 206, 
              headers: responseHeaders 
            });
          }
          
          return new Response(response.body, { headers: responseHeaders });
        }
      } catch (error) {
        return new Response(JSON.stringify({ 
          error: 'Proxy error', 
          message: error.message 
        }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    // Root endpoint
    return new Response(JSON.stringify({
      name: 'Megacloud Stream Proxy (Cloudflare)',
      version: '1.0.0',
      endpoints: {
        '/proxy?url=<url>': 'Proxy HLS streams',
        '/health': 'Health check'
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
};

function rewriteM3U8(manifest, baseUrl, proxyBase) {
  const lines = manifest.split('\n');
  const rewritten = [];
  
  for (const line of lines) {
    const trimmed = line.trim();
    
    // Handle tags
    if (trimmed.startsWith('#')) {
      if (trimmed.startsWith('#EXT-X-KEY')) {
        rewritten.push(rewriteKeyUri(trimmed, baseUrl, proxyBase));
      } else {
        rewritten.push(line);
      }
      continue;
    }
    
    if (!trimmed) {
      rewritten.push(line);
      continue;
    }
    
    // Rewrite segment URLs
    if (isSegmentUrl(trimmed)) {
      const absoluteUrl = trimmed.startsWith('http') 
        ? trimmed 
        : new URL(trimmed, baseUrl).href;
      const proxiedUrl = proxyBase + encodeURIComponent(absoluteUrl);
      rewritten.push(proxiedUrl);
    } else {
      rewritten.push(line);
    }
  }
  
  return rewritten.join('\n');
}

function isSegmentUrl(url) {
  const exts = ['.ts', '.m3u8', '.jpg', '.html', '.css', '.js', '.png', '.gif'];
  return exts.some(ext => url.toLowerCase().includes(ext)) ||
         url.includes('seg-') ||
         url.includes('iframe');
}

function rewriteKeyUri(tag, baseUrl, proxyBase) {
  const match = tag.match(/URI="([^"]+)"/);
  if (!match) return tag;
  
  const originalUri = match[1];
  const absoluteUri = originalUri.startsWith('http') 
    ? originalUri 
    : new URL(originalUri, baseUrl).href;
  
  const proxiedUri = proxyBase + encodeURIComponent(absoluteUri);
  return tag.replace(`URI="${originalUri}"`, `URI="${proxiedUri}"`);
}
