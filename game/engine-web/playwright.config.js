const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 30000,
  expect: { timeout: 10000 },
  use: {
    baseURL: 'http://127.0.0.1:8088',
    headless: true,
    launchOptions: {
      executablePath: process.env.HOME + '/.cache/ms-playwright/chromium-1223/chrome-linux64/chrome',
      args: ['--no-sandbox', '--disable-gpu'],
    },
  },
  webServer: {
    command: 'node scripts/start-test-server.js',
    port: 8088,
    reuseExistingServer: false,
    timeout: 60000,
  },
});
