# Course — authoring guide

Purpose: guidance and a template for creating a Course record and a corresponding documentation page.

Where to place
- Documentation file: add this file or a course-specific page under `docs/` (e.g. `docs/courses/intro-to-xyz.md`).
- Seed/test data: `data/Course__c.json` contains example Course records used for local test data.

Minimum Course fields (example mapping to Salesforce fields)
- `Name` — human title shown to learners.
- `DeveloperName` or `Slug` — short identifier used in URLs/config.
- `Description__c` — short summary shown on course cards.
- `Active__c` — whether course is published (boolean).
- `Module_Order__c` / `Lesson_Order__c` — ordering metadata (if present in object model).

Authoring template (markdown)

## Title

Short description (one paragraph).

### Objectives

- Bullet 1
- Bullet 2

### Lessons

- Lesson 1 — link to lesson doc or LWC: path or LWC name
- Lesson 2 — ...

### Notes

- Any special access-code or visibility rules for this course.

Example: create a Course record locally via SFDX

1) Quick CLI create (single record)

```bash
sfdx force:data:record:create -s Course__c -v "Name='Intro to TrailForge' Description__c='Short hands-on intro' Active__c=true"
```

2) Import from JSON (preferred for multiple records)

- Add or update `data/Course__c.json` with an array or data-tree format.
- Import with:

```bash
# data tree import (if you created a tree file)
sfdx force:data:tree:import -f data/Course__c.json

# or create via CLI from a JSON file using jq-derived values (example)
NAME=$(jq -r '.[0].Name' data/Course__c.json)
sfdx force:data:record:create -s Course__c -v "Name='$NAME'"
```

Where to look for examples in repo
- `data/Course__c.json` — seed/test data format used by the project.
- `force-app/main/default/lwc/` — LWC components that render course/lesson UI.
- `force-app/main/default/classes/` — services that reference Course/Module/Lesson objects (search for `Course__c` usages).

Commit guidance
- Put the course doc under `docs/` (or `docs/courses/`) and include any sample JSON under `data/` if you want it seeded in tests.
- Run `npm run prettier` to format files before commit.

If you want, I can:
- Create a concrete example file `docs/courses/intro-to-trailforge.md` and a sample `data/Course__c.json` entry now.
