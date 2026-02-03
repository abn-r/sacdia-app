// E2E Test Setup
// This file runs before all E2E tests

// Increase timeout for database connections
jest.setTimeout(30000);

// Suppress console.log during tests (optional)
// global.console.log = jest.fn();

// Clean up after all tests
afterAll(async () => {
  // Add any global cleanup here
  await new Promise((resolve) => setTimeout(resolve, 500));
});
