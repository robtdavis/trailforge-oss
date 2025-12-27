## TrailForge Access Code Plan (v1)
- Identity model: Contact
- Public Experience site: one-time access code per Contact
- Default expiry: 24 hours
- Expiry is configurable in hours
- Only users with Custom Permission `Trailforge_Access_Code_Override` (in `TrailForge_Permission_Set_Admin`) may override expiry hours
- Goal: get it working first; security hardening later (hashing/session token/etc.)




## TrailForge Access Code System - Implementation Complete

### Files Created

**Custom Objects:**
| Object | Files |
|--------|-------|
| `TrailForge_Access_Code__c` | Object + 9 fields (Contact, Code, Is_Active, Is_Used, Issued_On, Expires_On, Used_On, Used_Fingerprint, Issued_By) |
| `TrailForge_Access_Throttle__c` | Object + 3 fields (Fingerprint, Window_Start, Count) |
| `TrailForge_Settings__mdt` | Custom Metadata Type + Access_Code_Default_Expiry_Hours field |
| `Contact.TrailForge_Access_Code__c` | New field on Contact |

**Custom Metadata Record:**
- `TrailForge_Settings.Default` - Default expiry set to 24 hours

**Apex Classes:**
| Class | Purpose |
|-------|---------|
| `TrailForgeAccessSessionDTO` | DTO for session responses |
| `TrailForgeAccessCodeService` | Main service with all business logic |
| `TrailForgeAccessCodeService_Test` | Test class with 14 test methods |

**LWC Components:**
| Component | Purpose |
|-----------|---------|
| `trailforgeAccessCodeEntry` | External user code entry (Experience site) |
| `trailforgeAccessCodeAdmin` | Admin code generator (Contact record page) |

---

### Setup Checklist

1. **Add Admin LWC to Contact Page:**
   - Go to Setup → Object Manager → Contact → Lightning Record Pages
   - Edit the page → Drag `TrailForge Access Code Admin` to the sidebar
   - Save & Activate

2. **Add Entry LWC to Experience Site:**
   - Open Experience Builder
   - Add `TrailForge Access Code Entry` to your Welcome/Home page
   - Publish

3. **Assign Custom Permission for Override:**
   - Create/update permission set with `Trailforge_Access_Code_Override` custom permission
   - Assign to admins who need to override expiry hours

4. **Guest User Permissions (Experience Site):**
   - Ensure guest profile has access to Apex methods:
     - `TrailForgeAccessCodeService.validateAndBurn`
     - `TrailForgeAccessCodeService.getSession`
   - Grant Create/Update on `TrailForge_Access_Throttle__c` for rate limiting

---

### How It Works

**Admin Flow:**
1. Open a Contact record
2. In the Access Code Admin card, click "Generate Code"
3. Code format: `TF-XXXX-XXXX` (expires in 24h by default)
4. Copy the code and share with the learner

**External User Flow:**
1. User visits Experience site
2. Enters their access code
3. If valid: code is "burned" (one-time use) and session is created
4. Session stored in `sessionStorage` (not localStorage)
5. On page reload, session rehydrates automatically