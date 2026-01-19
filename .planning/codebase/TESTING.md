# Testing Patterns

**Analysis Date:** 2026-01-19

## Test Framework

**Primary Project (Swift/macOS):**
- Runner: XCTest (Apple's native testing framework)
- Config: Tests disabled in `Package.swift` with note:
  ```swift
  // Note: Tests require full Xcode installation (not just Command Line Tools)
  // Tests can be added when building with Xcode IDE
  ```
- Status: No active Swift tests in the main Voxa codebase

**Secondary Project (TypeScript/dev-browser):**
- Runner: Vitest 2.1.0
- Config: `.factory/skills/dev-browser/vitest.config.ts`

**Assertion Library:**
- Vitest built-in `expect` assertions

**Run Commands:**
```bash
# From .factory/skills/dev-browser directory:
npm run test              # Run all tests once (vitest run)
npm run test:watch        # Watch mode (vitest)
```

## Test File Organization

**Location:**
- Co-located with source in `__tests__` subdirectories
- Pattern: `src/{feature}/__tests__/{feature}.test.ts`

**Naming:**
- `{feature}.test.ts` (e.g., `snapshot.test.ts`)
- No spec files found (`.spec.ts` not used)

**Structure:**
```
.factory/skills/dev-browser/
├── src/
│   ├── snapshot/
│   │   ├── __tests__/
│   │   │   └── snapshot.test.ts    # Integration tests
│   │   └── browser-script.ts       # Source
│   ├── client.ts
│   └── ...
└── vitest.config.ts
```

## Test Configuration

**Vitest Config (`vitest.config.ts`):**
```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,              // Use global describe/test/expect
    environment: "node",        // Node environment (not jsdom)
    include: ["src/**/*.test.ts"],
    testTimeout: 60000,         // 60s for Playwright tests
    hookTimeout: 60000,
    teardownTimeout: 60000,
  },
});
```

## Test Structure

**Suite Organization:**
```typescript
import { chromium } from "playwright";
import type { Browser, BrowserContext, Page } from "playwright";
import { beforeAll, afterAll, beforeEach, afterEach, describe, test, expect } from "vitest";
import { getSnapshotScript, clearSnapshotScriptCache } from "../browser-script";

let browser: Browser;
let context: BrowserContext;
let page: Page;

beforeAll(async () => {
  browser = await chromium.launch();
});

afterAll(async () => {
  await browser.close();
});

beforeEach(async () => {
  context = await browser.newContext();
  page = await context.newPage();
  clearSnapshotScriptCache(); // Fresh state for each test
});

afterEach(async () => {
  await context.close();
});

describe("ARIA Snapshot", () => {
  test("generates snapshot for simple page", async () => {
    // Test implementation
  });
});
```

**Patterns:**
- Setup: Browser launched in `beforeAll`, context/page in `beforeEach`
- Teardown: Context closed in `afterEach`, browser in `afterAll`
- Isolation: Each test gets fresh browser context
- Async: All test functions are `async` for Playwright operations

## Mocking

**Framework:** No dedicated mocking library detected

**Patterns:**
- Real browser instances via Playwright (integration tests, not mocks)
- In-page JavaScript evaluation for testing DOM manipulation:
```typescript
async function getSnapshot(): Promise<string> {
  const script = getSnapshotScript();
  return await page.evaluate((s: string) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const w = globalThis as any;
    if (!w.__devBrowser_getAISnapshot) {
      // eslint-disable-next-line no-eval
      eval(s);
    }
    return w.__devBrowser_getAISnapshot();
  }, script);
}
```

**What to Mock:**
- Not applicable - current tests are integration tests using real browser

**What NOT to Mock:**
- Browser instances (real Playwright browsers used)
- DOM manipulation (tested against actual page content)

## Fixtures and Factories

**Test Data:**
```typescript
// Inline HTML fixtures for page content
await setContent(`
  <html>
    <body>
      <h1>Hello World</h1>
      <button>Click me</button>
    </body>
  </html>
`);
```

**Helper Functions:**
```typescript
// Helper to set page content
async function setContent(html: string): Promise<void> {
  await page.setContent(html, { waitUntil: "domcontentloaded" });
}

// Helper to select DOM element by ref ID
async function selectRef(ref: string): Promise<unknown> {
  return await page.evaluate((refId: string) => {
    const w = globalThis as any;
    const element = w.__devBrowser_selectSnapshotRef(refId);
    return {
      tagName: element.tagName,
      textContent: element.textContent?.trim(),
    };
  }, ref);
}
```

**Location:**
- Fixtures defined inline in test files
- Helper functions defined at top of test file

## Coverage

**Requirements:** None enforced

**View Coverage:**
```bash
# No coverage configuration detected
# Would need to add vitest coverage plugin
```

## Test Types

**Unit Tests:**
- Not present in current codebase
- Swift: Disabled in Package.swift
- TypeScript: Only integration tests

**Integration Tests:**
- Location: `.factory/skills/dev-browser/src/snapshot/__tests__/snapshot.test.ts`
- Scope: Browser automation testing with Playwright
- Approach: Real browser, real DOM, real page evaluation

**E2E Tests:**
- Framework: Playwright could support E2E
- Status: Not implemented for main Voxa application

## Common Patterns

**Async Testing:**
```typescript
test("generates snapshot for simple page", async () => {
  await setContent(`<html><body><h1>Hello World</h1></body></html>`);
  const snapshot = await getSnapshot();
  expect(snapshot).toContain("heading");
  expect(snapshot).toContain("Hello World");
});
```

**Regex Matching:**
```typescript
test("assigns refs to interactive elements", async () => {
  await setContent(`<html><body><button>Button 1</button></body></html>`);
  const snapshot = await getSnapshot();
  // Match ref pattern like [ref=e1]
  expect(snapshot).toMatch(/\[ref=e\d+\]/);
});
```

**Object Assertions:**
```typescript
test("selectSnapshotRef returns element for valid ref", async () => {
  // ... setup
  const result = (await selectRef(ref)) as { tagName: string; textContent: string };
  expect(result.tagName).toBe("BUTTON");
  expect(result.textContent).toBe("My Button");
});
```

**Boolean Assertions:**
```typescript
test("refs persist on window.__devBrowserRefs", async () => {
  await getSnapshot();
  const hasRefs = await page.evaluate(() => {
    const w = globalThis as any;
    return typeof w.__devBrowserRefs === "object" &&
           Object.keys(w.__devBrowserRefs).length > 0;
  });
  expect(hasRefs).toBe(true);
});
```

## Testing Gaps

**Main Application (Swift):**
- No automated tests for Voxa macOS application
- Requires Xcode IDE for XCTest (not Command Line Tools)
- Manual testing implied by user story verification process

**Recommendations for Future Testing:**
- Add XCTest targets in Xcode for:
  - `WhisperManager` transcription logic
  - `TextCleanupManager` text processing rules
  - `AudioManager` device selection scoring
  - `SnippetsManager` CRUD operations
- Consider UI testing with XCUITest for onboarding flow
- Add unit tests for TypeScript utility functions

---

*Testing analysis: 2026-01-19*
