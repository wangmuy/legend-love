const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..');

// 清理端口上的残留进程（首次启动时，reuseExistingServer=true 时后续复用）
try {
  execSync('fuser -k 8088/tcp 2>/dev/null', { timeout: 3000 });
} catch (_) {}

// Try dist/ first (built version), fall back to ROOT
const DIST = path.join(ROOT, 'dist');
const dir = fs.existsSync(DIST) ? DIST : ROOT;

const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.lua': 'text/plain',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  let f = req.url.split('?')[0];
  if (f === '/') f = '/index.html';
  const fp = path.join(dir, f);
  try {
    const c = fs.readFileSync(fp);
    res.writeHead(200, {
      'Content-Type': mime[path.extname(fp)] || 'application/octet-stream',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    });
    res.end(c);
  } catch (e) {
    res.writeHead(404);
    res.end('');
  }
});

const PORT = parseInt(process.env.PORT || '8088', 10);
server.listen(PORT, () => {
  console.log(`TEST_SERVER_READY:${PORT}`);
});

function shutdown() {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 3000).unref();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
