# 🛠 Skill: Decoupling ActiveRecord Callbacks via Service Objects

## Goal
Eliminate "Callback Hell" by migrating complex business logic and side effects from ActiveRecord models into explicit **Service Objects** using the **Updater/Creator pattern**. This improves maintainability, testability, and the predictability of domain logic.

## Trigger Criteria
Apply this skill when a model meets any of the following:
* **High Complexity:** Analysis via `callback_hell` gem shows a score > 20.
* **Implicit Logic:** Presence of `after_save`, `after_create`, or `after_commit` hooks containing business rules or multi-line logic.
* **Network Side Effects:** Callbacks that hit external APIs (Stripe, AWS, Slack) or deliver mailers.
* **Coupling:** Side effects are tied to the persistence lifecycle, causing transaction race conditions.

---

## 🗺️ Progress Tracking
To maintain state across long-running refactors, the agent **must** maintain a local orchestration file:
* **File:** Create `.refactor_plan.md` in the root directory before starting.
* **Content:** Use GFM checkboxes (`- [ ]`) to list the model, the callbacks identified, the target service name, and all discovered call-sites.
* **Lifecycle:** Update this file after every Phase. Delete the file only after all tests pass and call-sites are verified and user approves deletion.

---

## 📂 Discovery & Naming Convention

### 1. Pre-Implementation Audit (Anti-Duplicate Check)
Before creating a new file, you **must** check if a similar object already exists:
* **Search Strategy:** Run `find app/ -name "*<domain>*"` and `grep -r "<ModelName>"` to find existing logic.
* **Legacy Paths:** Audit `app/classes/`, `app/services/`, and `app/commands/`.
* **Action:** If a class like `Location::Updater` exists, refactor it into the new pattern rather than creating a duplicate.

### 2. Standardization
* **Namespace:** Services must be namespaced by domain (e.g., `Billing::`, `Users::`).
* **File Naming:** Use `creator.rb` for new records and `updater.rb` for existing records.
* **Class Pattern:** `<Domain>::Creator` or `<Domain>::Updater`.
* **Result Object:** Must return a `Struct.new(:success?, :record, :errors)`.

---

## 🏗 Architectural Standards

### 1. Principle of Minimalism
* **Universal Logic Only:** Only move logic to the Service Object if it is **required for every instance** of that domain action.
* **Preserve Call-Site Specificity:** Do not pull logic into the Service that is unique to a single Controller or Job.
* **Callback Focus:** The primary goal is to extract **existing model callbacks**, not to move all controller code into a service.

### 2. Logic Classification
| Category | Examples | Action | Why? |
| :--- | :--- | :--- | :--- |
| **Data Integrity** | Formatting, setting defaults, normalization. | **KEEP IN MODEL** | Ensures data is correct regardless of entry point. |
| **Business Logic** | Creating associated records, calculating totals. | **MOVE TO SERVICE** | These are processes, not inherent properties. |
| **Side Effects** | Emails, Slack pings, API updates. | **MOVE TO SERVICE** | Prevents expensive calls from blocking DB transactions. |
| **Dispatching** | Enqueuing a job via `after_commit`. | **KEEP IN MODEL** | This is the intended, decoupled use case for `after_commit`. |

---

## 🚀 Execution Workflow

### Phase 0: Planning & Checkpointing
1. **Create `.refactor_plan.md`:** List the target model, the specific callbacks to be moved, and all call-sites discovered via `grep`.
2. **Audit Existing Specs:** Check if current tests cover the callback side effects.
3. **Characterization Tests:** **Only** if existing coverage is missing, create a temporary spec to document baseline side effects.

### Phase 1: The Extraction Pattern (The "Shim")
1. **Granular Flags:** Add specifically named virtual attributes to the model (e.g., `attr_accessor :skip_geocode_callback`).
2. **Gate Legacy Hooks:** Update the model callback: `after_save :trigger_geocode, unless: :skip_geocode_callback`.

### Phase 2: Implementation (The "Orchestrator")
1. **Transaction Boundary:** Use `ActiveRecord::Base.transaction` only for database writes that require atomic rollback.
2. **Post-Commit Logic:** Move Emails and API calls **outside** the transaction block.
3. **Idempotency:** Use `find_or_create_by` logic for services that may be retried in jobs.

### Phase 3: Exhaustive Call-Site Replacement
1. **Search & Update:** Replace all instances of `.create`, `.save`, and `.update` for the model.
2. **The Reach:** Specifically audit `app/controllers/` and all nested directories (e.g., `app/controllers/api/`).
3. **Validation:** Check off each call-site in `.refactor_plan.md` as they are updated.

---

## ⚠️ Red Flag Checklist (Mandatory for Agents)
* [ ] **Plan Created?** Did you initialize and update `.refactor_plan.md`?
* [ ] **Minimalist Changes?** Does the Service only contain logic universal to the domain action?
* [ ] **Correct naming?** Did you use `creator.rb` or `updater.rb`?
* [ ] **Nested Controllers found?** Did you check `app/controllers/api/` for call-sites?
* [ ] **Network in transaction?** Ensure no API or Mailer calls are inside the `transaction` block.
* [ ] **Using `save!`?** Use the bang version so exceptions trigger the `rescue` block.
