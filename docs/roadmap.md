Perfect—thanks for the crisp decisions. Below is a **task-oriented execution plan** (no code) you can follow to ship the MVP quickly. Each task has concrete steps and a clear “Done” state.

---

# MVP Roadmap — Teacher Dashboard (Goals)

**Decisions locked in**

* Single writer (you). Student app will later write progress to other parts of the DB.
* List navigation = **click-through pages**.
* **Cascade delete** (delete a goal also deletes its descendants).
* **Reparent** allowed.
* Optional goals **always visible** (with a badge).
* Suggestions: **press Enter to add**, remove with “x”.
* **Autosave on blur** with a short debounce.

---

## Phase 0 — Hygiene & Scope (30–45 min)

### Task 0.1 — Field spec (single source of truth)

**Steps**

1. Create `docs/goal-spec.md` (one page).
2. List fields and defaults you will manage:

   * `title` (required)
   * `description` (optional plaintext)
   * `parentId` (nullable; root = null)
   * `order` (int; gapped increments, e.g., 1000)
   * `optional` (bool; default false)
   * `suggestions` (string list; default empty)
   * `tags` (string list; default empty)
3. Add behavior notes:

   * Cascade delete
   * Reparent allowed
   * Reorder within siblings
   * Autosave on blur (debounced)

**Done**

### Task 0.2 — Privacy policy for MVP

**Steps**

1. Decide read access now: **Private** (only you read/write) or **read-only for signed-in** users.
2. Add a 2-line note in `docs/security.md` describing the current policy and the later “student-app will write progress” scope.

**Done**

---

## Phase 1 — Firestore Setup (30–45 min)

### Task 1.1 — Seed structure & examples

**Steps**

1. Create collection **`goals`**.
2. Add 4–6 documents that cover:

   * 2 root goals (one with `optional: true`)
   * Each root has 1–2 children (at least one with `suggestions` and `tags`)
   * Use `order` values 1000, 2000, …
3. Copy the JSON of these docs into `seed/initial-goals.json` for reference.

**Done**

### Task 1.2 — Security rules (concept)

**Steps**

1. Implement rules that:

   * Allow only you to write to `goals`.
   * Allow read according to your privacy choice.
2. Note your UID in `docs/security.md` (do not store credentials in the repo).

**Done**

### Task 1.3 — Index checklist

**Steps**

1. Try the following queries in the Firestore console UI (or your app later):

   * List roots **sorted by `order`**.
   * List children **for a parent** sorted by `order`.
2. If Firestore requests indexes, create them and capture their descriptions in `docs/indexes.md`. Likely:

   * `(parentId ASC, order ASC)`
   * If you later filter optional within a parent: `(parentId ASC, optional ASC, order ASC)`

**Done**

---

## Phase 2 — Navigation & Pages (45–60 min)

### Task 2.1 — Route map (no code, just a list)

**Steps**

1. Document the route paths and page purpose in `docs/routes.md`:

   * `/goals` — shows root goals (click a row to open its children page)
   * `/goals/:id` — shows **children of that goal** + actions
   * `/goals/:id/edit` — editor for that goal
   * `/goals/new?parentId=…` — create form (optional parent preselected)

**Done when** the routes are listed and stable.

### Task 2.2 — “Row content & actions” spec

**Steps**

1. In `docs/ui-goal-list.md`, define:

   * What each row shows: `title`, optional badge (if `optional`), counts (`tags`, `suggestions`), an affordance to navigate into children.
   * Quick actions menu: **Add child**, **Edit**, **Delete**, **Reorder**.
   * Empty state text and CTA for: no goals / no children.
2. Define sort behavior: strictly ascending by `order`.

**Done when** the document is specific enough that someone else could build the list without guessing.

---

## Phase 3 — CRUD & Data Operations (60–90 min)

### Task 3.1 — Create & Edit behavior

**Steps**

1. In `docs/ui-goal-editor.md`, define:

   * Autosave triggers: on blur of `title`, `description`, `optional`, chips.
   * Debounce window (e.g., ~400–600ms) to avoid excessive writes.
   * Validation: `title` required (define minimum length if desired).
   * Parent selection:

     * On **create**: parent optional; if set, new goal appears at the **end** of that parent’s list.
     * On **edit**: parent **can be changed** (reparent).
   * Suggestions: input field that adds on Enter; duplicates not allowed; remove with “x”.
   * Tags: same pattern as suggestions.

**Done when** every field and interaction is unambiguous.

### Task 3.2 — Reorder policy

**Steps**

1. In `docs/reordering.md`, define:

   * Scope: **within siblings only**.
   * Interaction: Drag handle or “Move up/down” buttons (choose one now).
   * Numbering: gapped integers (1000 steps).
   * Normalization rule: if any two adjacent orders differ by <10 (or your threshold), renumber that sibling range by 1000 increments.

**Done when** the renumbering rule is written and future-you won’t question it.

### Task 3.3 — Reparent policy

**Steps**

1. In `docs/reparenting.md`, define:

   * Allowed from the editor.
   * On reparent:

     * Set `parentId` to the new parent (or null).
     * New `order`: append at end of the new sibling list (last + 1000).
   * Confirm any side effects:

     * Cascade delete still means the whole subtree goes if the **parent node** is later deleted.
   * (Breadcrumbs/ancestry are **not** required now; skip extra fields.)

**Done when** the steps to reparent are clear and predictable.

### Task 3.4 — Cascade delete policy

**Steps**

1. In `docs/delete.md`, define:

   * “Delete” on a node **removes the entire subtree**.
   * Confirmation dialog text: mention the number of descendants if feasible (optional).
   * Document a safety note: accidental deletes are destructive; consider trash/undo later (backlog).

**Done when** there’s no ambiguity about what “Delete” does.

---

## Phase 4 — Global UX (30–45 min)

### Task 4.1 — Loading & error surfaces

**Steps**

1. In `docs/ux-system.md`, specify:

   * Loading: global overlay during blocking actions; inline progress for lists.
   * Errors: transient snackbar for non-critical; dialog for destructive/failed delete/reparent.
   * Auto-dismiss: snackbars auto-dismiss; dialogs require explicit action.

**Done when** the same patterns can be applied everywhere without new decisions.

### Task 4.2 — Confirmations

**Steps**

1. List actions that require confirmation:

   * **Delete (cascade)** → “Delete goal and all sub-goals?”
   * **Reparent** if it changes many descendants (optional) → “Move goal to …?”
2. Set button labels (primary = action verb; secondary = Cancel).
3. Add this to `docs/ux-system.md`.

**Done when** destructive flows are covered.

---

## Phase 5 — Testing & Guardrails (45–60 min)

### Task 5.1 — Manual test script (keep in repo)

**Steps**

1. Create `tests/manual-mvp-checklist.md` with steps:

   * Create 2 roots; add children under one.
   * Add/remove suggestions; verify Enter-to-add works and no duplicates.
   * Toggle optional on a child; confirm badge shows.
   * Reorder siblings; refresh; verify order is persistent.
   * Reparent a child to the other root; confirm it appears at the end.
   * Delete a root with descendants; confirm **all** are gone.
   * Sign in as a non-owner (if applicable) to verify denied writes.

**Done when** the list runs in ~5 minutes and catches regressions.

### Task 5.2 — Emulator plan (optional but recommended)

**Steps**

1. Decide whether to use Firebase Emulator Suite.
2. If yes, add a one-line plan in `docs/dev-notes.md` describing how you’ll seed 5–10 example docs at startup (manual import for now is fine).

**Done when** you know how test data appears during development.

---

## Phase 6 — Student-App Future Hook (5–10 min now)

### Task 6.1 — Reserve namespaces only

**Steps**

1. In `docs/future-student-app.md`, note:

   * Student progress will live in different collections (e.g., `progress`, `attempts`) with separate write rules.
   * Teacher app will **not** write to those collections.
   * No schema needed now—just the boundary statement.

**Done when** the boundary is written so you won’t mix concerns later.

---

# “Definition of Done” for MVP (one glance)

* You can create/edit goals (with parent selection), add/remove suggestions and tags, toggle optional.
* You can **navigate** via click-through pages (roots → children → editor).
* You can **reorder** within siblings; the ordering policy and normalization are honored.
* You can **reparent** a goal; it appears at the end of the new sibling list.
* You can **cascade delete** any node; all descendants are removed.
* Loading and errors follow the **same** UI rules everywhere.
* Rules enforce your chosen privacy; only you can write.
* No “needs index” errors in your normal flows.
* The manual test script passes.

