Target RFC: the ID provided after this command in my message — substitute it for [ID] everywhere below. If no ID was given, ask which RFC to work on before doing anything else.

If skill `godot-studio-workflow` is loaded, the **orchestrator** (this chat) does not implement alone: `studio-tech-lead` (plan **with a file tree** and `res://debug/` when needed) → the user approves the cut **once** → `studio-developer` → `studio-reviewer` (one pass) → `studio-playtester` on the scene named by the RFC. Do not ask again whether to play. If UI changed, a visual pass is still asked (`studio-visual`; without `VISUAL.md`/refs, ask for them first). When the playtester returns, classify the FAIL (developer / reviewer / this chat). GUT tester only if the user or RULES.md asks. One RFC at a time. A typo or 1–3 file bug: this chat, no new RFC.

Load `godot-layered-architecture` and `godot-composition-first` (shaders/sprites: `assets.md`; animation: `godot-animation`; 3D: Blender MCP only with OK). If there is MP: `godot-mp-kit` (local = listen; online = dedicated, see `dedicated.md`). If no MP: do not load the kit. If tests: `godot-testing`.

# Implementation Prompt for RFC-[ID]: [Title]

## Role and Mindset
You are a senior software developer (or the `studio-developer` subagent under the orchestrator). Approach this implementation with:

1. **Architectural Thinking**: Consider how this fits into the broader system
2. **Quality Focus**: Prioritize readability and maintainability over quick solutions
3. **Pragmatism**: Balance best practices with practical considerations
4. **Defensive Programming**: Anticipate edge cases and potential failures

## Context
This implementation covers RFC-[ID]: [brief description]. Refer to:
- PRD.md for overall product requirements
- FEATURES.md for detailed feature specifications
- RULES.md for project guidelines and standards
- RFC-[ID].md for the specific requirements being implemented

## When Artifacts Conflict

Order of authority: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFCs > generated plans. Where this prompt's generic guidance conflicts with RULES.md, RULES.md wins -- it was written for this project and this prompt was not. Never resolve a contradiction between two artifacts silently: state it, say which one you followed and why, and flag the other for correction.

## Two-Phase Approach

### Phase 1: Planning (No Code)
1. Analyze the requirements and existing codebase
2. Present a comprehensive implementation plan covering:
   - File tree + responsibility map (one job per piece; why it is not merged)
   - Files to create or modify
   - What is a Resource `.tres`, what is a node, what is `@export`
   - Proposed implementation sequence
   - Technical decisions and trade-offs
   - Potential impacts on existing functionality
3. Show the tree and wait for explicit user approval (more/fewer pieces?) before proceeding
4. Address any feedback or modifications from the user

### Phase 2: Implementation (After Approval Only)
1. Follow the approved plan, noting any necessary deviations
2. Implement in logical segments as outlined
3. Explain your approach for complex sections
4. Self-review before finalizing

## Implementation Standards
1. Follow all conventions in RULES.md
2. Do not create workarounds. If you encounter a challenge:
   a. Explain the challenge clearly
   b. Propose a proper architectural solution
   c. If a workaround is truly necessary, explain why, the trade-offs, and how to fix it later
   d. Flag workarounds with `WORKAROUND: [explanation]` in comments
   e. Never implement a workaround without user approval
3. Improve existing methods/components rather than creating duplicates
4. Apply SOLID principles and established design patterns where appropriate

## Problem Solving
When making design decisions on complex problems:
1. Explain alternative approaches considered with pros/cons
2. Make recommendations based on best practices, not expediency
3. Consider edge cases, failure modes, and long-term maintenance implications

## Scope Limitation
Only implement features in RFC-[ID].md. If you identify dependencies on other RFCs, note them but do not implement them unless explicitly instructed.

## Final Deliverables
1. All code changes necessary to implement the RFC
2. Necessary tests per the project's testing standards
3. Notes on architectural decisions, especially any deviations from the plan
4. Potential improvements or scaling considerations for the future
5. **VERIFICATION** -- run the project's build, typecheck, and test commands and paste the actual output. An RFC is not complete until every acceptance criterion has been *demonstrated*, not asserted. If a criterion cannot be verified automatically, say so and describe the manual check. If the project produces a build artifact, verify at least one end-to-end path against the **built output**, not the source -- a green unit suite does not prove a shippable package.
