# PhiriLab Agent QA Contract

The browser exposes a deliberately narrow object:

```js
window.__PHIRILAB_QA__
```

External test runners such as Playwright may combine:

1. screenshot/video evidence,
2. `__PHIRILAB_QA__.snapshot()`,
3. allowlisted `__PHIRILAB_QA__.act(...)` UI actions,
4. assertions and regression reports.

## Security posture

Telemetry is read-only by default.

A game may register actions, but each action must be explicit and narrow. Version 1 for Survivors' Pool allows navigation between existing views only. It does not expose Supabase credentials, invite links, member names, chat messages, localStorage, remote-sync methods, destructive admin operations, result simulation, or persisted-state mutation.

## Example

```js
const caps = await page.evaluate(() => window.__PHIRILAB_QA__.capabilities());
const snap = await page.evaluate(() => window.__PHIRILAB_QA__.snapshot());
await page.screenshot({ path: "artifacts/dashboard.png", fullPage: true });
```

The agent should compare semantic state and visual state. A screenshot alone is insufficient evidence that game logic is correct.

## Contract principle

Agent observation and agent authority are separate. An agent may be able to see a state without being allowed to change it.
