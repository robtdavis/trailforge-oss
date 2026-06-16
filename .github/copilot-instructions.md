# Copilot / AI Agent Instructions — TrailForge

Purpose: Help AI coding agents become productive quickly in this Salesforce-native project.

1) Big picture (what to know first)
- TrailForge is a lightweight, Salesforce-native learning platform. Core source lives under [force-app/main/default](force-app/main/default).
- Server-side logic: Apex classes in [force-app/main/default/classes](force-app/main/default/classes) (look for `*Service.cls`, `*DAO.cls`, `*Controller.cls`). Example: `EnrollmentService.cls`, `QuizGuestService.cls`.
- UI: Lightning Web Components under [force-app/main/default/lwc](force-app/main/default/lwc) and legacy Aura under [force-app/main/default/aura](force-app/main/default/aura).
- Metadata packaging: manifest/package.xml and the repo is set up for Salesforce DX (see `sfdx-project.json`).

2) Key developer workflows & commands (verified from repo)
- Run JS lint: `npm run lint` (ESLint configured for LWC/Aura paths in `package.json`).
- Run unit tests for LWC: `npm run test` (runs `sfdx-lwc-jest`).
- Format code: `npm run prettier` and verify with `npm run prettier:verify`.
- Hooked workflow: husky + lint-staged run formatting and lint on precommit (see `package.json` > `lint-staged`).
- Common SFDX actions (use when deploying/testing to orgs):
  - Create scratch org: `sfdx force:org:create -f config/project-scratch-def.json -s -a TFDev` (project scratch def exists).
  - Deploy source: `sfdx force:source:deploy -x manifest/package.xml` or `sfdx force:source:push` for scratch orgs.
  - Run Apex tests: `sfdx force:apex:test:run --resultformat human --testlevel RunLocalTests`.

3) Project-specific conventions and patterns
- Apex test classes use suffix `_Test.cls` and have matching `*.cls-meta.xml` files (see [force-app/main/default/classes](force-app/main/default/classes)).
- Seed/test data under `data/` contains JSON (e.g., `Course__c.json`, `Lesson__c.json`). scripts/ contains helper Apex and SOQL scripts (`scripts/apex/*.apex`, `scripts/soql/*.soql`).
- Static assets and branding (Matilda logo) live under `force-app/main/default/staticresources` and are referenced in the root README.
- Naming: service/DAO/controller separation is used (examples: `EnrollmentService`, `LessonDAO`, `QuizGuestDAO`). Prefer to follow those boundaries when adding logic.

4) Integration points & external dependencies
- Uses Salesforce metadata (unlocked package / Experience Cloud). Public demo site and package-install URLs are in README.md.
- Local dev/test: `sfdx` CLI and `sfdx-lwc-jest` are required (devDependencies in `package.json`).

5) Files to read first when changing behavior
- `force-app/main/default/classes/EnrollmentService.cls` — central enrollment logic and existing tests (`EnrollmentService_Test.cls`).
- `force-app/main/default/classes/QuizGuestService.cls` and `QuizGuestDAO.cls` — quiz attempt and guest flows.
- `force-app/main/default/lwc/*` — components that render lesson and quiz UI.
- `manifest/package.xml` and `sfdx-project.json` — packaging and deploy boundaries.

6) Helpful tips for PRs and edits
- Keep Apex changes scoped to service/DAO/controller boundaries; add/extend unit tests (`*_Test.cls`) to match existing patterns.
- For UI changes, run `npm run test` and `npm run lint` locally; lint-staged will also run tests for related LWC files on commit.
- When in doubt about metadata to include, consult `manifest/package.xml` to see what the project packages.

7) What not to assume
- This repo targets Salesforce metadata and expects `sfdx` tooling — don't propose Node-only server changes.
- Authentication/workflows are Salesforce-specific (Experience site / access-code flow) — search for `access-code` references in the codebase and `data/` for examples.

If anything in this file looks unclear or you want more examples (e.g., representative code snippets from a specific class or LWC), tell me which area and I will expand the guidance. 
