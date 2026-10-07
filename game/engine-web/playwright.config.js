const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  // 仅运行规范测试套件；忽略历史上遗留的未跟踪调试/探针脚本（probe*/dbg-*/tmp_* 等），
  // 避免 npx playwright test 误跑 95 个离线探针文件。规范测试文件均为 git 跟踪文件。
  testIgnore: [
    '**/probe/**',
    '**/probe*.spec.js',
    '**/dbg-*.spec.js',
    '**/diag_*.spec.js',
    '**/tmp_*.spec.js',
    '**/zz-*.spec.js',
  ],
  timeout: 60000,
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
    reuseExistingServer: true,
    timeout: 60000,
  },
});
