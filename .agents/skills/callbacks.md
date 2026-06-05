# 🛠 Skill: Decoupling ActiveRecord Callbacks via Service Objects

## Goal
Eliminate "Callback Hell" by migrating complex business logic and side effects from ActiveRecord models into explicit **Service Objects** using the **Updater/Creator pattern**. This improves maintainability and prevents side effects from causing transaction race conditions.

## Trigger Criteria
Apply this skill when a model meets any of the following:
* **Implicit Logic:** Presence of `after_save`, `after_create`, or `after_commit` hooks containing multi-line business rules.
* **Network Side Effects:** Callbacks that hit external APIs or deliver mailers.
* **High Complexity:** Analysis shows significant coupling between the persistence lifecycle and business processes.

---

## 🗺️ Progress Tracking & Incrementalism

### 1. The "plan.md" Requirement
* **Mandatory File:** Create `plan.md` in the root directory before modifying any code.
* **Content:** List the model, all discovered call-sites, and a checklist for every specific callback targeted for extraction.
* **Incremental Updates:** Update this file after every phase; delete it only after the user approves final verification.

### 2. The "Rule of One" (Incremental Progress)
* **One at a Time:** Do not attempt to refactor multiple distinct side effects simultaneously.
* **Workflow:** Complete the full lifecycle (Shim → Service → Call-site Update) for **one** specific callback before starting the next.
* **Reasoning:** Migrating multiple callbacks at once (e.g., MGP refresh and Portal sync) often leads to context window overload and logic errors.

---

## 🏗 Execution Workflow

### Phase 1: The Extraction Pattern (The "Shim")
* **Granular Flags:** Add specifically named virtual attributes to the model to act as "gates".
* **Standard Template:**
  ```ruby
  attr_accessor :skip_side_effect_callback #
  after_commit :trigger_logic, unless: :skip_side_effect_callback #
  ```


#### 📂 Discovery & Tool Safety

##### 1. Pre-Implementation Audit
  * **Anti-Duplicate Check:** Search for existing logic in `app/classes/` or `app/services/` before creating new files.
  * **Refactor, Don't Duplicate:** If a class like `Location::Updater` exists, refactor it into the new pattern rather than creating a duplicate.

##### 2. Search Safety Guardrails
  * **Shell Command Isolation:** When requesting search results from the user, **never** place shell commands (e.g., `grep`, `find`) inside a code-edit block targeting an existing source file.
  * **Instructional Clarity:** Clearly state: "Please run these commands in your terminal" to prevent accidental file overwrites.
  * **Aider Protocol:** Use `/run` for shell commands if the environment supports it; otherwise, wait for user input before editing code.
  * Requesting Info: If you need the user to run search commands, provide them in a clear text block. Do not use a filename header for these blocks, as this triggers "edit format" errors in Aider.
  * Drafting the Plan: Once you receive search results, your next step is always to update the plan.md with the new findings.

---


### Phase 2: Implementation (The "Orchestrator")
* **Result Object:** Services must return a `Struct.new(:success?, :record, :errors)`.
* **Post-Commit Logic:** Move Emails and API calls **outside** the transaction block to prevent blocking database connections.
* **Minimalism:** Only move logic to the Service that is required for every instance of that domain action.

### Phase 3: Exhaustive Call-Site Replacement
* **Exhaustive Search:** Audit `app/controllers/` and all nested directories (e.g., `app/controllers/api/`) for every instance of `.create`, `.save`, and `.update`.
* **Validation:** Verify each call-site against the `plan.md` checklist.

---

## ⚠️ Red Flag Checklist (Mandatory for Agents)
* [ ] **Incrementalism Check:** Am I focusing on only **one** callback at this moment?
* [ ] **Shell Safety:** Are my `grep` commands isolated from my code-edit blocks?
* [ ] **Plan Initialized?** Is the `plan.md` created and updated?
* [ ] **Correct naming?** Did I use `creator.rb` or `updater.rb`?
* [ ] **Network in transaction?** Are API or Mailer calls outside the `transaction` block?
* [ ] **Using `save!`?** Does the Service use the bang version to trigger the `rescue` block?
