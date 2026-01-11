## 0) Goals, Scope, and Priorities

- **Goals:** ship features and fixes **safely**, **verifiably**, and **in as few iterations as possible**.
- **Default outputs (if not specified otherwise):**
  1. Plan (with risks/assumptions)
  2. TODOs
  3. Implementation notes
  4. Verification evidence (tests/build/cURL/Playwright)
  5. Handoff/PR summary.
- **Instruction precedence (highest → lowest):**
  1. Explicit user request for the current task.
  2. Organization compliance/policy.
  3. **This AGENTS.md.**
  4. Other repo rules/comments (.cursor/rules, code comments, etc.).
- **Communication style (towards the user):**
  - Concise, respectful, non-defensive.
  - Avoid overly rigid language; use _should/recommended/can_ unless safety/compliance demands otherwise.
  - When you must assume something, **state the assumption explicitly**.

---

## 1) Code Style, Principles, and Architecture

### 1.1 Readability & Documentation

- Write code as if it were for a **popular open-source project**:
  - Easy to read, easy to maintain, minimal surprises.
- **Inline comment logic as you write it**:
  - For any non-trivial logic, add English comments right above or next to the code.
  - Focus comments on **“why” and trade-offs**, not just “what”.
  - Assume a new team member or an external contributor should understand quickly by reading.
- Prefer **clear, explicit code** over clever/obscure solutions.
- Keep functions, methods, and classes **small and cohesive**:
  - One main responsibility per function/class.
  - Avoid god objects and long “script” functions.

### 1.2 Type Safety

- Aim for **strict typing** in all typed languages.
- In TypeScript (or similar typed languages):
  - **Do not use `any`** unless explicitly approved; prefer `unknown`, generics, or proper domain types.
  - Define clear interfaces/types for **domain objects** and **DTOs**.
- Prefer **immutable data** where reasonable and avoid hidden side effects.

### 1.3 Design & Clean-Code Principles

Always respect **SOLID**:

- **S – Single Responsibility Principle:**  
  Each module/class/function should have exactly one reason to change.
- **O – Open/Closed Principle:**  
  Open for extension, closed for modification (prefer polymorphism/strategies over `if/else` ladders).
- **L – Liskov Substitution Principle:**  
  Subtypes must be usable wherever their base type is expected, without breaking behavior.
- **I – Interface Segregation Principle:**  
  Prefer multiple small interfaces over monolithic “god” interfaces.
- **D – Dependency Inversion Principle:**  
  High-level modules should not depend directly on low-level modules; both depend on abstractions.

And also follow these supporting principles:

- **DRY (Don’t Repeat Yourself):**  
  Avoid duplicated logic; extract common behavior where it makes sense.
- **KISS (Keep It Simple, Stupid):**  
  Prefer the simplest design that works; avoid unnecessary abstraction.
- **YAGNI (You Aren’t Gonna Need It):**  
  Do not add features or abstractions “for future use” without concrete need.
- **Separation of Concerns:**  
  Split domain, application, infrastructure, and UI concerns.
- **Principle of Least Astonishment:**  
  APIs and behaviors should be intuitive for other engineers.

If you must trade off between principles, **opt for clarity and maintainability first**, then performance (unless the task explicitly prioritizes perf).

### 1.4 Architecture Defaults (DDD-lite, Hexagonal, Clean Architecture)

Choose architecture based on complexity:

- **Simple to medium projects** → use **DDD-lite + Hexagonal Architecture**:
  - Layers:
    - **Domain** (entities, value objects, domain services, domain events)
    - **Application** (use-cases/services, orchestrating domain logic)
    - **Ports** (interfaces/protocols to external systems)
    - **Adapters** (infrastructure: DB, HTTP, queues, 3rd party APIs, UI)
  - Keep domain logic **pure** and free of frameworks.
- **Complex or large projects** → use **Clean Architecture**:
  - Core domain and use-cases in the center, independent of frameworks.
  - Outer layers: infrastructure, frameworks, delivery mechanisms (HTTP, CLI, UI).
- Always:
  - Make dependencies **point inward** (outer layers depend on inner layers, not vice versa).
  - Keep controllers/handlers **thin**, delegating real work to use-cases/services.
  - Keep UI/presentation logic separate from business rules.

If architecture must change significantly or introduce new layers, treat it as **risky** and surface a short rationale before proceeding.

### 1.5 Strings, i18n, and UI Text

- All strings in code (error messages, logs, UI labels, validation messages, etc.) must be **in English**, unless the user explicitly asks otherwise.
- Avoid hard-coding user-facing strings in multiple places; centralize when appropriate (e.g., constants or i18n layer).

### 1.6 Logging & Debugging

- When adding debug logs:
  - Prefer a **structured `logging` module** (or framework-specific logger) instead of ad-hoc `print`/`console.log`.
  - Include a **clear prefix** (e.g., component/service name) and enough context to troubleshoot.
  - Do **not** log secrets or sensitive PII.
- When the user asks to remove debug logs, **clean them up properly** (do not leave commented-out clutter).

### 1.7 CLI & Runtime Commands

- **Shell:**  
  Run shell commands through `zsh` to ensure consistent behavior, e.g.:

  ```bash
  echo "hi"
  ```

* **Non-blocking behavior:**
  - Avoid commands that block the terminal for long periods.
  - For long-running or streaming commands, append `&` to run in background:

    ```bash
    some-long-running-command &
    ```

* **pm2 logs:**
  - When checking pm2 logs, **always use `--nostream`** to avoid blocking:

    ```bash
    pm2 logs your-service --nostream
    ```

* Do not introduce commands that would effectively “hang” the workspace without explicit user request.

### 1.8 Interaction Language (User-Facing)

- **Respond to and interact with the user in Vietnamese**,
  while keeping technical/programming terms in English when that makes them clearer.

---

## 2) Core Prompting Guidelines (per GPT‑5 for Coding)

<guidelines>
  <precision>
    Always ask yourself: “Is there ambiguity or contradiction in the request or codebase?”
    If yes, call it out and suggest 1–2 concrete interpretations.
  </precision>

<markdown_like_structure_when_reporting>
When reporting to the user or reviewer, use **markdown** so humans can read easily.
Keep the XML-like tags (e.g., `<research/>`, `<todo/>`, `<test_plan/>`, `<self_reflection/>`) in your head as structure hints,
but render them as normal markdown sections.
</markdown_like_structure_when_reporting>

<avoid_overly_firm_language>
Prefer “recommended/should/can” over hard imperatives like “must”,
unless it’s about safety, compliance, or a hard requirement in this file.
</avoid_overly_firm_language>

<self_reflection>
Before coding and before handoff, pause and check:

- Did you meet the success criteria and Definition of Done?
- Are key risks and trade-offs understood and documented?
  </self_reflection>

<control_eagerness>
Respect a tool/experiment budget; know when to ask for approval and when to just proceed.
</control_eagerness> </guidelines>

---

## 3) Default Workflow for New Features / Parts

> If there has been **no prior discussion/planning** for a new issue:
>
> - For **complex, ambiguous, or risky** work (arch changes, data/schema changes, security),
>   you **must create a plan** and share it for refinement/approval.
> - For **small, local, or clearly scoped** tasks that can be handled in one shot,
>   you can **skip asking for approval** and go straight to implementation, but still be explicit about assumptions.

### 3.1 Plan First

<planning>
  <intake>
    Clarify (if not already clear in the context):
    - Objective and scope.
    - Environment (dev/stage/prod).
    - Constraints (security, performance, compatibility, dependencies).
    - Deadlines or urgency, if relevant.
  </intake>

  <research>
    Use the Research Template in §3.2.
  </research>

<solution_overview ascii_flowchart="true">
Provide an ASCII flow that visualizes the proposed flow/data/decisions
for key interactions (request → handler → use-case → domain → persistence, etc.).
</solution_overview>

<acceptance_criteria>
Define **functional** and **non-functional** acceptance criteria:

- Functional behavior, edge cases, and error handling.
- Non-functional: SLO/latency, security expectations, UX/i18n/a11y basics.
  Define a **Definition of Done (DoD)**: code + verification evidence + docs.
  </acceptance_criteria>

<risks_and_mitigations>
Call out key risks and your mitigation or rollback plan (e.g., feature flags, toggles).
</risks_and_mitigations>

<reasoning_effort>high</reasoning_effort>

<ask_for_refinement>
For complex/risky changes:

- Share the **plan + ASCII flowchart + TODO list** for approval/refinement.
  For small/local changes:
- You can proceed without asking, but still keep the internal plan structured.
  </ask_for_refinement> </planning>

### 3.2 Research Template (required for non-trivial work)

<research_template> <context>
Summarize the business/technical background relevant to the problem. </context>

<current_implementation optional="true">
If there is existing code:

- Architecture, entry points, modules.
- API contracts, schemas, key logs/metrics.
  </current_implementation>

<issue_or_source>
Restate the problem (ticket, bug report, logs, stacktraces) in your own words.
</issue_or_source>

  <solution>
    Provide at least one recommended approach (plus an alternative if useful).
    For each option, outline:
    - Pros/cons.
    - DB/API/schema impact and migrations.
    - Feature flag / rollback strategy.
    - Testing and verification plan.
  </solution>
</research_template>

### 3.3 Example ASCII Flowchart

```text
[Client]
   |  POST /api/orders
   v
[Gateway] --> [Auth OK?] --no--> [401]
   | yes
   v
[OrderSvc] --> [Validate payload] --fail--> [422]
   | ok
   v
[Create DB txn] --> [Publish 'order.created'] --> [Commit] --> [200 OK]
```

### 3.4 Derive a TODO List From the Plan

<todo>
  - [ ] Define/confirm contract (OpenAPI/types/proto) and update docs.
  - [ ] Implement service/core logic + unit tests (where feasible).
  - [ ] Wire controller/handler + validation.
  - [ ] Add migration and/or feature flag (if needed).
  - [ ] Write integration/E2E tests or cURL scripts.
  - [ ] Add logs/metrics/tracing; review security (authn/authz/input sanitization).
  - [ ] Run verification per §4 and capture evidence.
  - [ ] Prepare PR with summary, decisions, and verification artifacts.
</todo>

---

## 4) Verify Before Calling the Work Done

> Repeat “fix → verify” until all checks pass.

<verification>
  <if_has_tests>
    Run tests and fix until all pass.
    Example commands (adjust to project tooling):

```
- `pnpm test` / `npm test`
- `go test ./...`
- `pytest -q`
- `cargo test`
```

</if_has_tests>

<if_no_tests>
If there are no tests yet, build/lint/type-check must be clean, e.g.:

````
```bash
pnpm build && pnpm typecheck && pnpm lint
```

or the project’s equivalents.
````

</if_no_tests>

<if_is_api>
For APIs, verify with `curl`:

- Health:

````
  ```bash
  curl -i http://localhost:3000/health
  ```

- Create:

  ```bash
  curl -i -X POST http://localhost:3000/api/items \
    -H "Content-Type: application/json" \
    -d '{"name":"Sample","qty":2}'
  ```

- Read:

  ```bash
  curl -i "http://localhost:3000/api/items?id=123"
  ```
````

</if_is_api>

<if_is_frontend_and_has_mcp_playwright>
For frontends with Playwright, create a minimal E2E scenario:

````
```ts
import { test, expect } from '@playwright/test';

test('basic flow', async ({ page }) => {
  await page.goto('http://localhost:5173');
  await page.getByRole('button', { name: 'Create Item' }).click();
  await page.getByLabel('Name').fill('Sample');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Created')).toBeVisible();
});
```

Save screenshots/video if available and attach to the PR.
````

</if_is_frontend_and_has_mcp_playwright>

<repeat_until_done>
If anything fails, fix and re-run verification until the Definition of Done is met.
</repeat_until_done> </verification>

---

## 5) Self-Reflection (Internal Rubric)

Use this before coding and before submitting a PR.

<self_reflection> <rubric>

- Is the scope and acceptance criteria crisp?
- Is there a feature flag or rollback plan if something goes wrong?
- Are tests/verification sufficient for happy path + key edge cases?
- Security: authn/authz, input sanitization, rate limits, secrets handling.
- Performance/SLO: latency and throughput acceptable? Any backpressure/caching?
- Compatibility/migrations: API/ABI/DB safe and documented?
- Observability: structured logs, metrics, tracing available and useful?
- Documentation: updated README/usage/examples? </rubric>

  <decision>
    Note briefly:
    - Why the chosen approach beats alternatives.
    - When you would pivot (what “red signals” look like).
  </decision>
</self_reflection>

---

## 6) Control the Agent’s Eagerness & Tool Budget

<persistence>
  <tool_budget>
    - Discovery/reading: ≤ 3 passes over the codebase/context before asking for confirmation on big decisions.
    - Build/test iterations: as needed until pass, but keep changes scoped.
  </tool_budget>

<check_ins>
Ask for explicit user approval when:

- The plan is new or the scope is ambiguous.
- You intend to change architecture, schemas, or introduce security/data risk.
Otherwise, for straightforward tasks, you **can proceed without asking**.
</check_ins>

  <assumptions>
    When you must proceed under uncertainty, document your assumptions clearly
    in the plan/PR so the user can confirm or correct them later.
  </assumptions>
</persistence>

---

## 7) Definition of Done (DoD)

<definition_of_done>

- [ ] Acceptance criteria are demonstrably met.
- [ ] Tests pass OR (if tests do not exist) build/lint/typecheck pass and
      API/UX basics are verified via cURL/Playwright/manual checks.
- [ ] API/contract/docs updated (OpenAPI/types) + runnable examples.
- [ ] Logs/metrics/tracing reasonable; no PII or secrets leaked.
- [ ] Evidence attached (test output, screenshots, logs, screencasts).
      </definition_of_done>

---

## 8) PR / Handoff Template

<pr_template>

  <title>feat(scope): concise summary</title>

  <context>
    What problem this solves and why now.
  </context>

  <changes>
    Main modules/endpoints/schemas affected.
  </changes>

  <assumptions>
    Non-obvious decisions and constraints.
  </assumptions>

<test_plan>
How to run tests/build; cURL/Playwright/manual steps.
</test_plan>

  <evidence>
    Attach logs, screenshots, and artifacts.
  </evidence>

  <risks>
    Security/data/performance risks + rollback/feature-flag plan.
  </risks>

  <checklist DoD="see §7">
    - [x] All boxes checked.
  </checklist>
</pr_template>

**API Verification Snippet (optional PR comment):**

```bash
# Build/Typecheck
pnpm i && pnpm typecheck && pnpm build

# Unit tests
pnpm test --reporter=dot

# Smoke via cURL
curl -i http://localhost:3000/health
curl -i -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Sample","qty":2}'
curl -i "http://localhost:3000/api/items?id=123"
```

---

## Appendix A — Making Autonomous “One‑Shot” Development More Reliable

1. **Contract-first development:**
   Lock OpenAPI/types/proto and generate server/client stubs to avoid drift.
2. **Feature flags/canary by default;** design easy rollback.
3. **Strict quality gates:** lint + type-check mandatory; deny merge on warnings in critical areas.
4. **Minimal but meaningful tests:** unit tests for core logic + one E2E happy path where feasible.
5. **Observability built-in:** structured logs with correlation IDs, basic latency/error metrics, tracing where available.
6. **Security checklist:** authn/authz, input validation, rate limiting, secret handling, dependency scans.
7. **Performance expectation:** document SLOs (e.g., P95 < 250 ms) and small micro-benchmarks for hot paths if risk is suspected.
8. **Compatibility discipline:** backward-compatible APIs where possible; if breaking, version and deprecate gracefully.
9. **Safe migrations:** idempotent DB migrations with tested rollback.
10. **UX quality bar:** accessibility roles/labels; no broken states; responsive where relevant; error/empty states handled.
11. **Runbook:** README includes run commands, env vars, test/build commands, seed data, demo credentials.
12. **Executable examples:** cURL/HTTPie snippets and short client code samples that run as-is.
13. **Risk sweep before merge:** check PII/secrets leakage, N+1 queries, deadlocks, race conditions, timezones.
14. **Support matrix:** define minimum browser/SDK/runtime versions and smoke them in CI if feasible.
15. **Lightweight ADRs:** store key decisions in `docs/adr/xxxx.md` (one-page ADRs).

---

## Appendix B — Standard Response Skeleton for a New Request (No Prior Plan)

<research>
  <context>Summarize relevant background.</context>
  <current_implementation>Describe existing code/architecture if present.</current_implementation>
  <issue_or_source>Problem statement, logs, stacktraces, code excerpts.</issue_or_source>

  <solution>
    <option index="A">Approach A with pros/cons.</option>
    <option index="B">Approach B with pros/cons.</option>
    <recommendation>Pick A/B because of {reasons}.</recommendation>
  </solution>
</research>

<solution_overview>
ASCII flowchart of the proposed flow.
</solution_overview>

<todo>
  - [ ] Implementation tasks from §3.4.
</todo>

<questions optional="true">
  - Confirm edge cases: ...
</questions>

---

## Appendix C — Quick Safety & Quality Checklists

**Security**

- Authentication/authorization enforced; least privilege.
- Input sanitization and output encoding.
- Rate limiting/throttling on sensitive endpoints.
- No secrets or PII in code, logs, or artifacts.

**Observability**

- Structured logs with request IDs or correlation IDs.
- Key metrics: request count, latency, error rate.
- Tracing spans for critical paths (if infra supports it).

**Performance**

- Baseline latency profile; avoid N+1 queries or data explosions.
- Consider caching/backpressure for bursty flows.

**Docs & Handoff**

- README/OpenAPI/types updated.
- Example requests/responses and end-to-end steps.
- Clear rollback plan.
