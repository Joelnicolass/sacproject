You are guiding a project through an RFC-driven development workflow with these stages.

The orchestrator (`godot-studio-workflow`) runs these steps; the user does not have to type every slash if they asked to make the game. `/test-strategy` is optional if there are no tests.

| # | Stage | Artifact | Command / Prompt |
|---|-------|----------|------------------|
| 1 | Create PRD | PRD.md | `/create-prd` |
| 2 | Verify PRD | PRD.md (improved) + PRD-REVIEW.md | `/verify-prd` |
| 3 | Extract features | FEATURES.md | `/extract-features` |
| 4 | Generate rules | RULES.md | `/generate-rules` |
| 5 | Visual guide (if there is a look) | VISUAL.md | `/create-visual-guide` |
| 6 | Generate RFCs | RFCs/ folder + RFCS.md | `/generate-rfcs` |
| 7 | Testing strategy | TEST-STRATEGY.md | `/test-strategy` (optional) |
| 8 | Implement RFCs (one by one, in order) | Code | `/implement-rfc <id>` |
| 9 | Review each implementation | `reviews/REVIEW-RFC-<id>.md` | `/review-rfc <id>` |
| 10 | Manage changes (whenever requirements move) | `changes/CHANGE-REQUEST-<nnn>.md` | `/manage-changes` |
| 11 | Status check (anytime) | this report | `/workflow-status` |

`/test-strategy` comes **before** implementation on purpose: a test plan written after the code is a coverage audit, not a plan. `VISUAL.md` may be missing if there is no look yet; then the visual pass does not run.

**Short path (no PRD or RFCs):** a valid state, not a gap. The truth lives in `FEATURES.md` (`F<n>` IDs + criteria) and `.studio/MEMORY.md` / Engram (decisions, next step). Report per feature instead of per RFC and do not recommend generating PRD/RFCs just to fill the table.

Inspect the current project to determine workflow progress:

1. Which artifacts exist: PRD.md, PRD-REVIEW.md, FEATURES.md, RULES.md, VISUAL.md, RFCS.md, RFCs/ folder, reviews/, changes/, `.studio/MEMORY.md`?
2. Which RFCs appear implemented in the codebase versus not yet started? Compare each RFC's acceptance criteria against the actual code — do not assume an RFC is done just because code exists.
3. Which RFCs have been reviewed? Check `reviews/` for a report per implemented RFC — an implemented RFC with no review is the most common real-world gap, and reviews are exactly what gets skipped under deadline.
4. Are there open change requests in `changes/` whose decisions are still pending?
5. Any signs of drift: code that contradicts the PRD or RULES.md, features in the codebase with no RFC, RFCs skipped out of order?

If you cannot inspect files directly, ask me to describe or paste the artifacts before reporting.

Then report:

1. **Status table** — each workflow stage with its artifact and status (Done / In progress / Missing / Stale)
2. **Per-RFC or per-feature progress** — implementation and review status side by side, one row per RFC (or per `F<n>` from `FEATURES.md` if there are no RFCs):

   ```
   RFC-001  implemented ✅   reviewed ❌
   RFC-002  implemented ✅   reviewed ❌
   RFC-003  implemented ✅   reviewed ✅
   ```

   A single "reviews done" row hides which RFCs were actually reviewed. Report them individually.
3. **Inconsistencies** — anything drifted, skipped, or contradictory, with file references
4. **Next step** — the single recommended next action, with the exact command or prompt to run
