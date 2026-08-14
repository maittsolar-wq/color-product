const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 30000,
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:8080',
    viewport: { width: 430, height: 900 }
  },
  reporter: [['list']]
});
