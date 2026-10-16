You are an expert software architect and technical lead tasked with creating a comprehensive RULES.md file based on the Product Requirements Document (PRD.md) and features list (FEATURES.md), or the documents provided in the conversation.

Create a clear, structured RULES.md that establishes technical and general guidelines for AI assistance during the development process. These rules will ensure consistency, quality, and alignment with project requirements.

If any critical information is missing or unclear, ask specific questions before proceeding.

## SCOPE THE CHECKLIST TO THE PRODUCT TYPE

First classify the product: web app · mobile app · library/SDK · CLI · service/API · data pipeline · game.

Apply only the sections and checks that fit that type. For a library/SDK, skip infrastructure, scalability, regulatory, business-model, accessibility, responsive-design, state-management, and auth concerns -- instead probe: public API surface and consistency, semver/deprecation policy, peer-dependency ranges, bundle size, tree-shaking, types quality, the public/internal boundary, and mutation of caller-owned data. Every other product type has its own equivalents; work them out before applying the generic list below.

State which product type you classified and which checks you skipped. Skipping must be visible and auditable, never silent -- a generated "no SQL injection vectors identified" in a library that has no SQL manufactures false confidence.

## GROUND THE RULES IN EXISTING CODE

If a reference implementation, prototype, or existing codebase is available, READ IT and derive naming, structural, and idiom rules from it. Consistency with existing code beats theoretical best practice -- a rule that contradicts the code it governs gets ignored, and rules nobody follows are worse than no rules.

Generate the RULES.md by:

1. TECHNOLOGY STACK DEFINITION:
   - Identify core technologies mentioned or implied in the PRD/features
   - Specify versions for each technology, and VERIFY every one against the actual registry before writing it down (`npm view <pkg> version`, `pip index versions <pkg>`, or the registry's latest endpoint). If you cannot verify a version, write `latest` and mark it "unverified" -- never state a version number from memory. Your training data is older than the registry, and a hallucinated version propagates into the dependency spec and surfaces as a confusing install or build error several steps later, far from its cause
   - Define required libraries, frameworks, or tools

2. TECHNICAL PREFERENCES:
   - Naming conventions for files, components, variables, etc.
   - Code organization principles (folder structure, modularity)
   - Architectural patterns to follow
   - Standards for data handling, state management, and API interactions
   - Performance optimization strategies
   - Security practices and requirements

3. DEVELOPMENT STANDARDS:
   - Testing requirements and coverage expectations (for a game: optional unless the user asks; if tests exist, bind to the real runner)
   - Error handling and logging requirements
   - For a Godot game: composition, `@export`/inspector, Resource `.tres` types, UI in the product language and IDs in English. Cite `godot-layered-architecture` and `godot-composition-first`. Look: if `VISUAL.md` exists, cite it (authority below RULES). Shaders: Godot Shaders and Shadertoy (see composition `assets.md`). 2D sprites: ask; references; `godot-animation`; Aseprite MCP only with OK. If 3D: ask; Blender MCP ([lab/mcp-server](https://www.blender.org/lab/mcp-server/)) only with OK + references; export glTF. Cite `godot-mp-kit` **only** if there is MP: local/Wi-Fi = listen-server; online = dedicated (`host_dedicated`, same project, VPS, do not fake LAN). If no MP, do not cite the kit. Playtest in the binary (`godot-playtest`, module [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)) ≠ GUT. Automated tests: `godot-testing` (GUT for GDScript, GdUnit4 for C#) **only** if the user asks. Architecture Clean **or** standard, whichever was chosen.
   - Do not copy a web checklist (responsive, auth, SQL) onto a game that has none of those

4. IMPLEMENTATION PRIORITIES:
   - Core features vs. enhancements (MoSCoW)
   - Phased implementation approach
   - Quality thresholds that must be met

5. GENERAL GUIDELINES:
   - Rules for following requirements precisely
   - Expectations for code quality, readability, and maintainability
   - Standards for completeness (no TODOs or placeholders)
   - How to handle uncertainty or ambiguity

6. AGENT CONFIGURATION:
   - If the project uses an AI coding agent, recommend wiring RULES.md into its config so the rules stay in context: reference it from CLAUDE.md (Claude Code), AGENTS.md (Codex and others), or .cursor/rules/ (Cursor)

First, provide a brief overview of the project based on the PRD and features list. Then create the RULES.md content. Ensure the rules are specific enough to guide development but flexible enough to allow for creative problem-solving.

## SELF-CHECK BEFORE FINISHING

- Recount every summary table from the actual content. Never carry a count forward from earlier in your own output.
- Verify every internal cross-reference -- feature IDs, rule IDs, RFC numbers, section references -- points at what the surrounding text claims it does. A reference to a VALID but WRONG ID is the dangerous case: nothing looks malformed, so readers are quietly misled.
- Confirm no two tables in the document disagree with each other.
- State that you ran this check and what it turned up.
