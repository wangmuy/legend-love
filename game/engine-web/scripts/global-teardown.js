const { execSync } = require('child_process');
const net = require('net');

module.exports = async () => {
  // Try multiple methods to free port 8088
  const methods = [
    () => execSync('fuser -k 8088/tcp 2>/dev/null', { timeout: 3000 }),
    () => execSync('lsof -ti :8088 | xargs kill -9 2>/dev/null', { timeout: 3000 }),
    () => execSync("ps aux | grep 'start-test-server' | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null", { timeout: 3000 }),
  ];
  for (const method of methods) {
    try { method(); } catch (_) {}
  }
  // Verify port is free
  await new Promise(resolve => {
    const server = net.createServer();
    server.once('error', () => resolve(false));
    server.listen(8088, () => { server.close(); resolve(true); });
  });
};