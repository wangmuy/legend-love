const { execSync } = require('child_process');
const net = require('net');

module.exports = async () => {
  // Kill the test server (reuseExistingServer=false, Playwright does not manage shutdown)
  try {
    execSync('fuser -k 8088/tcp 2>/dev/null', { timeout: 3000 });
  } catch (_) {}
  // Verify port is free
  await new Promise(resolve => {
    const server = net.createServer();
    server.once('error', () => resolve(false));
    server.listen(8088, () => { server.close(); resolve(true); });
  });
};