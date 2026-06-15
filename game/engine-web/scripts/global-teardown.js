const { execSync } = require('child_process');

module.exports = async () => {
  try {
    execSync('fuser -k 8088/tcp 2>/dev/null', { timeout: 3000 });
  } catch (_) {}
};