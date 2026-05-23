import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { NextResponse } from 'next/server';

export async function GET() {
  // Try multiple possible paths for the HTML file
  const possiblePaths = [
    join(process.cwd(), 'public', 'login.html'),
    join(process.cwd(), '.next', 'server', 'public', 'login.html'),
    join('/var/task', 'public', 'login.html'),
    join('/opt/buildhome/repo', 'public', 'login.html'),
  ];
  
  let html = null;
  let htmlPath = '';
  
  for (const p of possiblePaths) {
    if (existsSync(p)) {
      html = readFileSync(p, 'utf-8');
      htmlPath = p;
      break;
    }
  }
  
  if (!html) {
    // Fallback: return a page that auto-redirects
    const fallbackHtml = `<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<title>OGOTEL Cloud - Connexion</title>
<script>
// Debug info
console.log('CWD:', '${process.cwd()}');
console.log('Files checked:', ${JSON.stringify(possiblePaths)});
window.location.href = '/landing';
</script>
</head><body><p>Redirection vers OGOTEL Cloud...</p></body></html>`;
    return new NextResponse(fallbackHtml, {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    });
  }
  
  return new NextResponse(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
