const { execSync } = require('child_process');
const net = require('net');

module.exports = async () => {
  // With reuseExistingServer=true, the server persists across test runs.
  // Only clean up if the port is already in use by a stale process.
  const isFree = await new Promise(resolve => {
    const server = net.createServer();
    server.once('error', () => resolve(false));
    server.listen(8088, () => { server.close(); resolve(true); });
  });
  if (!isFree) return; // Server is running, let it persist
  // Port is free, nothing to clean up
};