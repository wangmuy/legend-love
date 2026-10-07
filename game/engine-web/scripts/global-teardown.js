const { execSync } = require('child_process');

module.exports = async () => {
  // reuseExistingServer=false: Playwright manages web server lifecycle
  // No need to clean up port 8088 — just kill leftover Chrome processes
  try {
    execSync('pkill -f "chrome.*--disable-gpu" 2>/dev/null', { timeout: 3000 });
  } catch (_) {}
};