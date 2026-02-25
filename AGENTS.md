# Agent Workflow (Codex)

These instructions are for the coding agent only. They are not CI/CD rules and must not be enforced on developers.

## Frontend validation requirement

After every frontend change made by the agent (especially Perspective view changes), the agent must run:

1. `scripts/scan.sh local`
2. A Playwright validation against the correct Perspective client URL(s) for the changed view(s)
3. Save a screenshot in:
   - `build/playwright/`

The agent validate if the playwright screenshot actually looks like it expected it to look and keep iterating until the desired result is achieved.

## How to resolve the correct Perspective URL

Do not hardcode only `/client/TestProject`. Resolve URL(s) dynamically from project configuration.

Source of truth in this repo:
- Project name: folder name under `projects/` (example: `TestProject`)
- Perspective page routes: `projects/<Project>/com.inductiveautomation.perspective/page-config/config.json`
- Route definitions are under `pages`:
  - key = page URL path (for example `/`, `/line`, `/line/oee`)
  - `viewPath` = view resource path (for example `OEEOverview`)

Build the browser URL as:
- `http://localhost:9088/data/perspective/client/<Project><pagePath>`
- Examples:
  - project `TestProject`, page path `/` -> `http://localhost:9088/data/perspective/client/TestProject/`
  - project `TestProject`, page path `/line/oee` -> `http://localhost:9088/data/perspective/client/TestProject/line/oee`

Validation rule for the agent:
1. Detect which Perspective view file(s) were changed.
2. Find all `pages[*].viewPath` entries that reference those changed views.
3. Validate each matching URL with Playwright.
4. If no direct mapping is found, still validate at least the project root page (`/<Project>/`) and report that mapping was missing.
