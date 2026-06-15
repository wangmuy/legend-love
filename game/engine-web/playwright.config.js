const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 30000,
  expect: { timeout: 10000 },
  globalTeardown: require.resolve('./scripts/global-teardown'),
  use: {
    baseURL: 'http://localhost:8088',
    headless: true,
    launchOptions: {
      executablePath: process.env.HOME + '/.cache/ms-playwright/chrome-linux64/chrome',
      args: ['--no-sandbox', '--disable-gpu'],
    },
  },
  webServer: {
    command: 'node scripts/start-test-server.js',
    port: 8088,
    reuseExistingServer: false,
  },
});
