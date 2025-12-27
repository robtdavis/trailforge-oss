# TrailForge LMS - Engineering Instructions

**Version:** 1.0  
**Last Updated:** November 21, 2025  
**Maintainers:** Robert Davis, George (future), Claude (AI assistant)

---

## 1. Project Purpose

### Mission Statement

TrailForge is a **Learning Management System (LMS)** built as a Salesforce managed package. It enables organizations to deliver training courses to learners (Contacts) without requiring Salesforce User licenses.

### Core Value Propositions

1. **Contact-Based Learning:** Learners are represented as Contacts, not Users. This allows external learners, customers, partners, and employees to access training without consuming Salesforce licenses.

2. **Flexible Content Delivery:** Support multiple content types (Markdown, HTML, Video, PDF, URL, Quiz) to accommodate diverse learning materials.

3. **Progress Tracking:** Automatically track learner progress at the lesson level and aggregate to course completion percentages.

4. **Packaged Solution:** Designed for distribution as a managed package on AppExchange, deployable to any Salesforce org with minimal configuration.

### Target Users

- **Learners (End Users):** Contacts who consume training content and track their progress.
- **Administrators:** Salesforce users who create courses, modules, lessons, and manage enrollments.
- **Instructors/Facilitators:** Users who monitor learner progress and provide support (future).

### Out of Scope (Phase 1)

- Real-time collaboration (forums, chat)
- Gamification (badges, leaderboards)
- Advanced quiz types (essay, file upload)
- Video hosting (use external platforms like YouTube/Vimeo)
- SCORM compliance
- Integration with external LMS platforms

---

## 2. Data Model (Source of Truth)

### Object Hierarchy

```
Course__c (Top-level container)
    └─ Module__c (Logical grouping) [Master-Detail]
         └─ Lesson__c (Individual content unit) [Master-Detail]

Contact (Learner)
    └─ Enrollment__c (Tracks learner's course progress) [Lookup]
         ├─ Course__c (Which course) [Lookup]
         └─ Progress__c (Tracks lesson-level progress) [Lookup]
              └─ Lesson__c (Which lesson) [Lookup]
```

### Object Definitions

#### **Course__c**
- **Purpose:** Top-level training container
- **Sharing Model:** ReadWrite
- **Key Fields:**
  - `Name` (Text) - Required
  - `Description__c` (Long Text) - Optional
  - `Estimated_Duration__c` (Number) - Minutes, optional
  - `Thumbnail_URL__c` (Text) - Optional
  - `Difficulty__c` (Picklist) - Beginner | Intermediate | Advanced
  - `Active__c` (Checkbox) - Default true
- **Deletion:** Cascades to all child Modules and Lessons (Master-Detail)

#### **Module__c**
- **Purpose:** Logical grouping of lessons within a course
- **Sharing Model:** ControlledByParent
- **Key Fields:**
  - `Name` (Text) - Required
  - `Course__c` (Master-Detail to Course__c) - Required
  - `Order__c` (Number) - Optional, not enforced
  - `Summary__c` (Long Text) - Optional
- **Deletion:** Cascades to all child Lessons
- **Parent:** Course__c (Master-Detail relationship)

#### **Lesson__c**
- **Purpose:** Individual learning unit containing content
- **Sharing Model:** ControlledByParent
- **Key Fields:**
  - `Name` (Text) - Required
  - `Module__c` (Master-Detail to Module__c) - Required
  - `Content_Type__c` (Picklist) - Markdown | HTML | URL | Video | PDF | Quiz
  - `Content_Body__c` (Long Text) - For Markdown/HTML content
  - `External_URL__c` (URL) - For external resources
  - `Duration_Minutes__c` (Number) - Optional
  - `Order__c` (Number) - Optional, not enforced
- **Deletion:** Restrict if Progress records exist
- **Parent:** Module__c (Master-Detail relationship)

#### **Enrollment__c**
- **Purpose:** Junction object linking a learner (Contact) to a Course
- **Sharing Model:** ReadWrite
- **Key Fields:**
  - `Name` (Auto Number) - ENR-{00000000}
  - `Contact__c` (Lookup to Contact) - Required, Restrict delete
  - `Course__c` (Lookup to Course__c) - Restrict delete
  - `Status__c` (Picklist) - Not Started | In Progress | Completed
  - `Progress_Percentage__c` (Percent) - Auto-calculated, 0-100%
  - `Enrollment_Date__c` (Date) - Optional, not set by code
  - `Completion_Date__c` (Date) - Optional
  - `Certificate_URL__c` (URL) - Optional
  - `Account__c` (Formula Text) - Derived from Contact__r.Account.Name
- **Unique Key:** (Contact__c, Course__c) - should be unique
- **Deletion:** SetNull on Progress__c.Enrollment__c

#### **Progress__c**
- **Purpose:** Tracks learner progress on individual lessons
- **Sharing Model:** ReadWrite
- **Key Fields:**
  - `Name` (Auto Number) - PRG-{00000000}
  - `Contact__c` (Lookup to Contact) - Required, Restrict delete
  - `Lesson__c` (Lookup to Lesson__c) - Restrict delete
  - `Enrollment__c` (Lookup to Enrollment__c) - SetNull delete
  - `Status__c` (Picklist) - Not Started | In Progress | Completed
  - `Started_On__c` (DateTime) - When lesson was started
  - `Completed_On__c` (DateTime) - When lesson was completed
- **Unique Key:** (Contact__c, Lesson__c, Enrollment__c)
- **Critical Rule:** ALL queries MUST filter by `Enrollment__c` to prevent cross-enrollment data leakage

#### **Quiz__c** (Future)
- **Purpose:** Assessment/quiz definition
- **Status:** Schema defined, not yet integrated

#### **QuizResponse__c** (Future)
- **Purpose:** Learner's quiz answers
- **Status:** Schema defined, not yet integrated

#### **CertificateTemplate__c** (Future)
- **Purpose:** Certificate generation templates
- **Status:** Schema defined, not yet implemented

### Field Constraints

#### Required Fields (Database Level)
- **NONE.** All custom fields are marked `required="false"` in metadata to allow flexible data loading.
- Required fields are enforced at UI/validation rule level, not database level.

#### Fields That Exist But Are NOT Used by Code
1. **`Order__c`** on Module__c and Lesson__c
   - Exists in schema for future drag-and-drop ordering
   - Code does NOT query or set this field
   - All queries order by `Name` alphabetically
   - **Reason:** Avoids org-specific field dependencies

2. **`Enrollment_Date__c`** on Enrollment__c
   - Exists in schema with default value `TODAY()`
   - Code does NOT set this field programmatically
   - **Reason:** Avoids field accessibility issues across orgs

#### Formula Fields
- **`Account__c`** on Enrollment__c
  - Formula: `Contact__r.Account.Name`
  - Works for both Business and Person Accounts
  - Read-only, auto-calculated

### Relationship Rules

1. **Master-Detail Cascades:**
   - Course deletion → deletes all Modules → deletes all Lessons
   - Module deletion → deletes all Lessons
   - **Warning:** Be careful with bulk deletes in production

2. **Lookup Restrictions:**
   - Contact deletion → BLOCKED if Enrollments exist
   - Lesson deletion → BLOCKED if Progress exists
   - Course deletion (via Lookup) → BLOCKED if Enrollments exist

3. **SetNull Behavior:**
   - Enrollment deletion → sets Progress.Enrollment__c to NULL (does NOT cascade delete)

---

## 3. Architectural Decisions

### DAO Pattern (Data Access Object)

**Decision:** All SOQL queries MUST reside in the DAO layer. Controllers and services delegate to DAO for all data access.

**Rationale:**
- Centralized query logic for easier maintenance
- Easier to mock/test
- Single source of truth for data access patterns
- Prevents query sprawl across controllers

**Implementation:**
- All queries in `EnrollmentDAO.cls`
- Controllers are thin orchestration layers
- DAO methods return empty collections (never null) when no data found
- DAO methods validate inputs (null checks)

**Pattern Example:**
```
LWC Component
    ↓ @AuraEnabled call
Controller (orchestration + DTO transformation)
    ↓ delegate
DAO (SOQL queries)
    ↓ return raw SObjects
Controller (transform to DTOs)
    ↓ return
LWC Component
```

### Service Layer (Business Logic)

**Decision:** Business logic (calculations, state transitions, validation) resides in Service classes, not Controllers or DAO.

**Implementation:**
- `EnrollmentService.cls` handles progress recalculation
- Controllers call Services for business operations
- Services call DAO for data access
- Services do NOT contain SOQL (delegate to DAO)

**Pattern Example:**
```
Controller.markLessonComplete()
    ↓ find/create Progress record
    ↓ update Progress.Status__c
    ↓ call Service
EnrollmentService.recalculateEnrollmentProgress()
    ↓ call DAO for lessons
    ↓ call DAO for progress records
    ↓ calculate percentage
    ↓ update Enrollment.Progress_Percentage__c
```

### Contact-Based Learner Model

**Decision:** Use `Contact` object for learners, NOT `User`.

**Rationale:**
- External learners (customers, partners) don't have Salesforce User licenses
- Reduces license costs
- More flexible for multi-org deployments
- Allows Person Accounts and Business Accounts

**Implications:**
- User → Contact mapping required for "My Learning" page
- Lesson Player requires explicit Contact selection (no implicit User context)
- Security model based on Contact ownership, not User role hierarchy

**User → Contact Mapping Strategy:**
- Match `User.Email` to `Contact.Email`
- Assumes 1:1 relationship (one Contact per User email)
- Falls back to empty list if no Contact found

### No Field Dependencies

**Decision:** Code does NOT assume optional fields exist or are accessible.

**Rationale:**
- Managed packages deploy to diverse orgs
- Field-level security may vary
- Some orgs may delete optional fields

**Implementation Rules:**
1. **Never query fields not essential to functionality**
2. **Never set fields programmatically unless critical**
3. **Use `Schema.SObjectType` checks for optional field access**
4. **Order queries by `Name` (always exists) rather than `Order__c` (optional)**

**Example - Avoided Pattern:**
```apex
// BAD - assumes Order__c exists
SELECT Id, Name, Order__c FROM Module__c ORDER BY Order__c
```

**Example - Correct Pattern:**
```apex
// GOOD - orders by Name (always exists)
SELECT Id, Name FROM Module__c ORDER BY Name
```

### Progress Scoping

**Decision:** ALL Progress__c queries MUST filter by `Enrollment__c`.

**Rationale:**
- Prevents data leakage between enrollments
- Handles re-enrollment edge case (same Contact + Course, different Enrollment)
- Ensures data integrity

**Critical Rule:**
```apex
// REQUIRED pattern
SELECT Id, Status__c FROM Progress__c 
WHERE Enrollment__c = :enrollmentId 
  AND Lesson__c IN :lessonIds

// FORBIDDEN pattern (missing Enrollment filter)
SELECT Id, Status__c FROM Progress__c 
WHERE Contact__c = :contactId 
  AND Lesson__c IN :lessonIds
```

### Automated Progress Recalculation

**Decision:** Enrollment progress percentage is auto-calculated whenever Progress records change.

**Implementation:**
- Record-Triggered Flow on Progress__c (After Save)
- Flow invokes `EnrollmentRecalcInvoker` (Invocable Apex)
- Invocable calls `EnrollmentService.recalculateEnrollmentProgress()`

**Calculation Logic:**
1. Count total lessons in course
2. Count completed Progress records for enrollment
3. Calculate: `(completed / total) * 100`
4. Set `Progress_Percentage__c` with 2 decimal places
5. Update `Status__c`:
   - 0% → "Not Started"
   - 1-99% → "In Progress"
   - 100% → "Completed"

**Alternative Considered:** Batch job nightly recalculation
**Rejected Because:** Real-time updates provide better UX

---

## 4. Naming Conventions

### Salesforce Metadata

#### Custom Objects
- **Pattern:** PascalCase + `__c` suffix
- **Examples:** `Course__c`, `Enrollment__c`, `Progress__c`
- **Label vs API Name:**
  - Label: Human-readable (e.g., "Course")
  - API Name: Machine-readable (e.g., `Course__c`)

#### Custom Fields
- **Pattern:** Snake_Case + `__c` suffix
- **Examples:** `Content_Type__c`, `Progress_Percentage__c`, `Enrollment_Date__c`
- **Boolean Fields:** Prefix with "Is" or use adjective
  - Good: `Active__c`, `Is_Published__c`
  - Bad: `Published__c` (ambiguous)

#### Relationships
- **Lookup/Master-Detail Field:** Singular + `__c`
  - Example: `Contact__c`, `Course__c`, `Module__c`
- **Relationship Name:** Plural
  - Example: `Enrollments`, `Modules`, `Lessons`
- **Relationship Label:** Human-readable plural
  - Example: "Enrollments", "Progress Records"

### Apex Code

#### Classes
- **Pattern:** PascalCase, descriptive noun or noun+verb
- **Suffixes:**
  - `DAO` - Data Access Object (e.g., `EnrollmentDAO`)
  - `Service` - Business logic (e.g., `EnrollmentService`)
  - `Controller` - LWC controller (e.g., `LessonPlayerController`)
  - `Invoker` - Invocable Apex (e.g., `EnrollmentRecalcInvoker`)
  - `Test` - Test class (e.g., `EnrollmentDAO_Test`)
- **Examples:**
  - `EnrollmentDAO` (data access)
  - `LessonPlayerController` (LWC controller)
  - `EnrollmentService` (business logic)

#### Methods
- **Pattern:** camelCase, verb-first
- **Examples:**
  - `getLearnerOptions()` - retrieves data
  - `markLessonComplete()` - performs action
  - `recalculateEnrollmentProgress()` - performs calculation
  - `findEnrollment()` - finds single record
  - `searchContacts()` - searches multiple records

#### Variables
- **Pattern:** camelCase
- **Collections:** Plural
  - `List<Contact> contacts`
  - `Map<Id, Progress__c> progressByLesson`
  - `Set<Id> lessonIds`
- **Single Records:** Singular
  - `Enrollment__c enrollment`
  - `Contact contact`

#### DTO Classes (Data Transfer Objects)
- **Pattern:** PascalCase + `DTO` suffix
- **Nested in Controller:** Inner classes for scope
- **Examples:**
  - `LessonContextDTO`
  - `EnrollmentDTO`
  - `SelectOptionDTO`
  - `ModuleDTO`
  - `LessonDTO`

### LWC Components

#### Component Names
- **Pattern:** camelCase
- **Examples:**
  - `myLearningShell`
  - `lessonPlayer`
  - `courseBuilder` (future)
  - `lessonContentViewer` (future)

#### JavaScript Files
- **Pattern:** camelCase, matches component name
- **Examples:**
  - `myLearningShell.js`
  - `lessonPlayer.js`

#### HTML Files
- **Pattern:** camelCase, matches component name
- **Examples:**
  - `myLearningShell.html`
  - `lessonPlayer.html`

#### CSS Files
- **Pattern:** camelCase, matches component name
- **Examples:**
  - `myLearningShell.css`
  - `lessonPlayer.css`

### Permission Sets

#### Naming
- **Pattern:** PackageName_Role
- **Examples:**
  - `TrailForge_Learner`
  - `TrailForge_Admin`
  - `TrailForge_Instructor` (future)

### Tabs

#### Naming
- **Pattern:** PackageName_ObjectOrPage
- **Examples:**
  - `TrailForge_Courses`
  - `TrailForge_My_Learning`

---

## 5. UI/UX Principles

### User Experience Goals

1. **Simplicity First:** Minimize clicks to complete common tasks
2. **Progressive Disclosure:** Show advanced options only when needed
3. **Immediate Feedback:** Provide visual confirmation for all actions
4. **Error Prevention:** Validate inputs client-side before server calls
5. **Mobile-Friendly:** Design for responsive, touch-friendly interactions

### Design Patterns

#### Learner-Facing UI

**My Learning Dashboard:**
- Card-based layout for enrollments
- Progress bars for visual completion tracking
- Clear status badges (Not Started, In Progress, Completed)
- One-click navigation to course

**Lesson Player:**
- Explicit learner selection (no implicit User context)
- Collapsible module/lesson tree structure
- Status indicators per lesson (checkmarks, badges)
- One-click "Mark Complete" action
- Real-time progress updates (no page refresh)

**Lesson Content Viewer (Future):**
- Markdown/HTML rendering with syntax highlighting
- Embedded video player (YouTube/Vimeo)
- PDF viewer (iframe or native browser)
- Navigation controls (Previous/Next Lesson)
- Sticky "Mark Complete" button

#### Admin-Facing UI

**Course Builder (Future):**
- Drag-and-drop module/lesson ordering
- Inline editing (no page navigation)
- Preview mode (see learner view)
- Bulk actions (publish, archive)

**Analytics Dashboard (Future):**
- Charts for completion rates
- Learner progress heatmaps
- Filtering by date range, course, learner

### Component Responsibilities

#### **myLearningShell**
- **Purpose:** Dashboard for logged-in learner's enrollments
- **Data Source:** `TrailForgeMyLearningController.getMyEnrollments()`
- **Actions:**
  - Display enrollment cards
  - Navigate to Lesson Player

#### **lessonPlayer**
- **Purpose:** Lesson tracking and progress management
- **Data Source:** `LessonPlayerController`
- **Actions:**
  - Search/select learner (Contact)
  - Load course structure
  - Display module/lesson tree
  - Mark lessons complete
  - Update progress in real-time

#### **lessonContentViewer** (Future)
- **Purpose:** Render lesson content
- **Data Source:** Lesson__c record
- **Actions:**
  - Render Markdown/HTML
  - Embed external URL (iframe)
  - Display video (YouTube, Vimeo)
  - Show PDF (iframe or download)
  - Navigate between lessons

### Accessibility Requirements

1. **Keyboard Navigation:** All interactive elements accessible via keyboard
2. **ARIA Labels:** Screen reader support for all controls
3. **Color Contrast:** WCAG AA compliance (4.5:1 ratio)
4. **Focus Indicators:** Visible focus states for all inputs
5. **Alt Text:** All images have descriptive alt text

---

## 6. Responsibilities of Claude

### Claude's Role

Claude is an AI assistant specializing in Salesforce development. Claude assists with:

1. **Code Generation:** Writing Apex classes, LWC components, metadata
2. **Refactoring:** Improving code quality, maintainability, performance
3. **Debugging:** Identifying and fixing errors
4. **Documentation:** Creating technical documentation
5. **Best Practices:** Enforcing Salesforce and TrailForge conventions

### Claude's Operating Principles

#### Code Quality Standards
- **Always follow DAO pattern** - No inline SOQL in controllers
- **Always validate inputs** - Null checks, type validation
- **Always return safe values** - Empty collections, not null
- **Always use `with sharing`** - Enforce sharing rules
- **Always handle exceptions** - Try-catch blocks in `@AuraEnabled` methods

#### Documentation Standards
- **Inline comments:** Explain "why", not "what"
- **Method headers:** Document purpose, parameters, return values
- **Complex logic:** Add comments for non-obvious algorithms
- **TODO markers:** Flag incomplete or temporary code

#### Testing Standards (Future)
- **75% code coverage minimum** - Required for managed package
- **Test data factories** - Reusable test data creation
- **Positive and negative tests** - Happy path + error cases
- **Bulk operation tests** - Governor limit validation

#### When to Push Back

Claude should challenge requests that violate:
1. **DAO pattern** - Inline SOQL in controllers
2. **Field dependencies** - Code assuming optional fields exist
3. **Progress scoping** - Queries without Enrollment__c filter
4. **Security** - Missing `with sharing` or FLS checks
5. **Governor limits** - Non-bulkified code

Claude should **NOT** push back on:
1. **New features** - Unless they conflict with core principles
2. **Design preferences** - UI/UX decisions are user's choice
3. **Naming conventions** - As long as consistent within project

### Claude's Workflow

1. **Understand Request:** Ask clarifying questions if ambiguous
2. **Plan Approach:** Outline changes before implementing
3. **Implement:** Write code following conventions
4. **Validate:** Check for errors, test coverage, best practices
5. **Deploy:** Provide deployment commands
6. **Document:** Update status.md or instructions.md as needed

---

## 7. Responsibilities of George

### George's Role

George is a developer who may work on TrailForge when Robert is unavailable. George is responsible for:

1. **Bug Fixes:** Resolving production issues
2. **Feature Development:** Building new functionality per backlog
3. **Testing:** Writing test classes for code coverage
4. **Code Review:** Ensuring code follows TrailForge conventions
5. **Documentation:** Updating status.md after major changes

### George's Operating Rules

#### Before Making Changes
1. **Read status.md** - Understand current state
2. **Read instructions.md** - Understand conventions and principles
3. **Ask Claude** - Use AI assistant for code generation/refactoring
4. **Test in test org** - Always deploy to `test-0db2pzqvescl@example.com` first

#### While Making Changes
1. **Follow DAO pattern** - No inline SOQL in controllers
2. **Follow naming conventions** - PascalCase classes, camelCase methods
3. **Add comments** - Explain non-obvious logic
4. **Handle errors** - Try-catch in all `@AuraEnabled` methods
5. **Validate inputs** - Null checks, required field validation

#### After Making Changes
1. **Deploy to test org** - Validate deployment success
2. **Test manually** - Click through UI, verify behavior
3. **Update status.md** - Mark tasks complete, add notes
4. **Commit to Git** - Clear commit messages
5. **Document edge cases** - Add notes for future developers

#### When to Ask for Help

George should consult Robert or Claude when:
1. **Architectural decisions** - New patterns or major refactors
2. **Data model changes** - Adding objects, fields, relationships
3. **Security concerns** - Sharing rules, FLS, CRUD
4. **Performance issues** - Governor limit errors, slow queries
5. **Unclear requirements** - Ambiguous feature requests

### George's Priorities

**High Priority (Do First):**
1. Production bugs (data loss, errors, security)
2. Test class development (blocking managed package)
3. Permission set creation (blocking managed package)

**Medium Priority (Do Next):**
1. Lesson Content Viewer (critical UX gap)
2. Course Builder admin UI
3. Reporting dashboards

**Low Priority (Do Later):**
1. UX polish (styling, animations)
2. Nice-to-have features (certificates, badges)
3. Performance optimizations (unless blocking)

---

## 8. Future Considerations

### Managed Package Roadmap

#### Phase 1: MVP (Current)
- ✅ Core data model (Course, Module, Lesson, Enrollment, Progress)
- ✅ DAO architecture
- ✅ Lesson Player (tracking only, no content viewer)
- ✅ My Learning dashboard
- ⏳ Test classes (in progress)
- ⏳ Permission sets (in progress)

#### Phase 2: Content Delivery
- ⏳ Lesson Content Viewer (Markdown, HTML, Video, PDF)
- ⏳ Course Builder admin UI
- ⏳ Quiz integration (Quiz__c, QuizResponse__c)
- ⏳ Certificate generation (CertificateTemplate__c)

#### Phase 3: Analytics & Reporting
- ⏳ Learner progress dashboards
- ⏳ Course effectiveness reports
- ⏳ Completion rate analytics
- ⏳ Time-to-completion metrics

#### Phase 4: Advanced Features
- ⏳ Discussion forums (learner collaboration)
- ⏳ Live sessions (webinar integration)
- ⏳ Gamification (badges, leaderboards)
- ⏳ Mobile app (Salesforce Mobile optimized)

### Namespace Considerations

**Current State:** No namespace (unmanaged package)

**Future State:** Managed package with namespace

**Namespace Selection Criteria:**
- Short, memorable (e.g., `tfg`, `trail`, `lms`)
- Not already taken on AppExchange
- Consistent with package name (TrailForge → `tfg`)

**Migration Plan:**
1. Create new packaging org with namespace
2. Deploy all metadata with namespace prefix
3. Test thoroughly (all queries, relationships, LWC work)
4. Create managed package version
5. Install in test org, validate
6. Publish to AppExchange

**Breaking Changes:**
- API names change (e.g., `Course__c` → `tfg__Course__c`)
- LWC imports change (e.g., `@salesforce/apex/LessonPlayerController` → `@salesforce/apex/tfg.LessonPlayerController`)
- SOQL queries must use namespaced names
- Custom settings/metadata require namespace prefix

### Scalability Considerations

#### Current Limits (Single-Record Operations)
- Lesson Player: Loads one course at a time
- Progress tracking: One lesson at a time
- Enrollment creation: One enrollment at a time

#### Future Enhancements (Bulk Operations)
- Bulk enrollment creation (CSV import)
- Batch progress tracking (mark all lessons complete)
- Scheduled batch jobs (nightly analytics recalculation)

#### Governor Limit Monitoring
- SOQL queries: 100 per transaction (current usage: ~5-10)
- DML statements: 150 per transaction (current usage: 1-2)
- Heap size: 6 MB synchronous (current usage: minimal)
- CPU time: 10 seconds synchronous (current usage: <1 second)

**Risk Areas:**
- Large courses (100+ lessons) may hit query limits
- Concurrent progress updates may cause locking
- Bulk enrollment creation needs batching

### Integration Points (Future)

#### External Systems
- **Single Sign-On (SSO):** SAML integration for learner authentication
- **Video Platforms:** YouTube, Vimeo, Wistia API integration
- **Content Repositories:** Google Drive, Dropbox, SharePoint
- **Email Notifications:** SendGrid, Mailchimp for course announcements
- **Calendar Integration:** Google Calendar, Outlook for scheduled sessions

#### Salesforce Platform
- **Experience Cloud:** Embed LWC components in community pages
- **Einstein Analytics:** Advanced reporting and predictive insights
- **Einstein Bots:** Chatbot for learner support
- **Marketing Cloud:** Drip campaigns for course completion
- **Service Cloud:** Case creation for learner questions

---

## 9. Known Constraints

### Salesforce Platform Constraints

#### User Object Limitations
- **Cannot create Master-Detail to User** - Salesforce restriction
- **Cannot use `required=true` on User lookups** - Delete constraint issues
- **Cannot cascade delete User records** - Salesforce system object

**Workaround:** Use Contact-based learner model (current implementation)

#### Governor Limits
- **100 SOQL queries** per transaction
- **150 DML statements** per transaction
- **10 seconds CPU time** (synchronous)
- **12 MB heap size** (synchronous)
- **50,000 records** per SOQL query

**Mitigation:** Bulkify all operations, use collections, avoid loops with SOQL/DML

#### Master-Detail Relationships
- **Cannot reparent** after creation
- **Cascade deletes** cannot be prevented
- **Maximum 2 Master-Detail** relationships per object

**Impact:** Course deletion deletes all child Modules and Lessons (cannot prevent)

#### Formula Field Limitations
- **Cannot reference across more than 10 relationships**
- **Cannot use in SOQL WHERE clause** (some formulas)
- **Recalculates on read** (performance impact)

**Example:** `Enrollment__c.Account__c` formula references `Contact__r.Account.Name`

### Package Distribution Constraints

#### Managed Package Requirements
- **75% test coverage** - All Apex classes must be tested
- **No hardcoded IDs** - Record IDs must be dynamic
- **No hardcoded URLs** - Use custom metadata or settings
- **Namespace required** - All objects/fields must be namespaced
- **Protected Apex** - Source code hidden from subscribers

#### AppExchange Listing Requirements
- **Security review** - Salesforce security team approval
- **Trialforce template** - Demo org for trial installations
- **Documentation** - Installation guide, user manual, release notes
- **Support policy** - Response time SLA for bugs/questions

### Technical Debt

#### Current Known Issues

1. **MyLearningController uses inline SOQL**
   - **Impact:** Inconsistent with DAO pattern
   - **Priority:** Medium
   - **Effort:** 1 hour
   - **Fix:** Move queries to EnrollmentDAO

2. **EnrollmentService uses legacy DAO method**
   - **Impact:** Progress queries don't filter by Enrollment__c
   - **Priority:** Medium
   - **Risk:** Data leakage on re-enrollment
   - **Effort:** 30 minutes
   - **Fix:** Update to use `getProgressForEnrollmentAndLessons()`

3. **No test classes**
   - **Impact:** Cannot package without 75% coverage
   - **Priority:** High (blocker)
   - **Effort:** 6-8 hours
   - **Fix:** Write test classes for all Apex

4. **Flow metadata not in workspace**
   - **Impact:** Progress recalculation may be broken in fresh deployments
   - **Priority:** Medium
   - **Effort:** 1 hour
   - **Fix:** Export flow from org, commit to Git

5. **No lesson content viewer**
   - **Impact:** Learners can track progress but cannot view content
   - **Priority:** High (critical UX gap)
   - **Effort:** 8-12 hours
   - **Fix:** Build LWC for Markdown, HTML, Video, PDF rendering

### Deployment Constraints

#### Target Org Requirements
- **Salesforce Edition:** Enterprise, Unlimited, or Developer
- **API Version:** 60.0 or higher
- **Features Required:**
  - Lightning Experience enabled
  - Contacts object accessible
  - Custom objects allowed

#### Pre-Deployment Checklist
1. Validate metadata compiles (`sf project deploy start --dry-run`)
2. Run all test classes (`sf apex run test`)
3. Check code coverage (>75% required)
4. Verify no hardcoded IDs in code
5. Test in sandbox before production

#### Post-Deployment Checklist
1. Assign permission sets to users
2. Create sample Course/Module/Lesson records
3. Test end-to-end learner flow
4. Monitor debug logs for errors
5. Validate progress recalculation works

### Operational Constraints

#### Data Volume Limits
- **Maximum courses:** Unlimited (practical limit: ~10,000)
- **Maximum lessons per course:** Unlimited (practical limit: 500)
- **Maximum enrollments per contact:** Unlimited (practical limit: 100)
- **Maximum progress records:** Unlimited (governed by storage)

**Storage Impact:**
- Average Course: ~1 KB
- Average Module: ~0.5 KB
- Average Lesson: ~10 KB (with content)
- Average Enrollment: ~0.5 KB
- Average Progress: ~0.2 KB

**Example Calculation:**
- 100 courses × 10 modules × 20 lessons = 20,000 lessons (200 MB)
- 1,000 learners × 5 enrollments × 200 lessons = 1M progress records (200 MB)
- **Total:** ~400 MB data storage

#### Performance Benchmarks
- Lesson Player load time: <2 seconds (for 50-lesson course)
- Mark lesson complete: <1 second
- Progress recalculation: <1 second (for 100-lesson course)
- My Learning dashboard load: <1 second (for 10 enrollments)

**Degradation Points:**
- >100 lessons per course: Pagination recommended
- >50 concurrent users: Consider caching strategies
- >10,000 progress records per enrollment: Archive old enrollments

---

**End of Instructions Document**

