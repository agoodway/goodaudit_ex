## Context

GoodAudit's dashboard provides account-scoped views for the overview and API key management, but account administration itself has no UI. The sidebar "Settings" link currently navigates to `/users/settings` (a global user-level page for email/password), not to anything account-specific. Account owners who need to rename their account, manage team roles, inspect HMAC keys, or delete the account must use the API or database directly. The `GA.Accounts` context already has CRUD functions for accounts and account users (`get_account/1`, `add_user_to_account/3`, `update_account_user_role/2`, `remove_user_from_account/2`), but several gaps exist: there is no `update_account/2`, no `delete_account/1`, no `rotate_hmac_key/1`, and no `list_account_members/1` that returns users with their roles.

This change adds a tabbed account settings LiveView that consumes and extends the existing `GA.Accounts` context, with role-based access control enforced at the LiveView level.

## Goals / Non-Goals

**Goals:**
- Provide a single settings page with tabbed navigation for General, Members, and Security.
- Allow account owners to manage all aspects of the account including deletion.
- Enforce role-based visibility: owners see everything, admins see General + Members (read-only roles), members see General only.
- Wire the existing sidebar Settings link to the new account-scoped route.
- Add missing context functions (`update_account/2`, `delete_account/1`, `rotate_hmac_key/1`, `list_account_members/1`).

**Non-Goals:**
- Member invitation flow (placeholder only — full invite system is a separate change).
- Account billing or subscription management.
- Audit logging of settings changes (can be layered later via the existing audit pipeline).
- Account suspension/unsuspension from the UI (status is displayed read-only).
- Bulk member operations (import, bulk role change).
- Two-factor authentication or re-authentication for sensitive actions beyond confirmation dialogs.

## Decisions

### Tabbed LiveView with live_action

Each tab maps to a `live_action` atom (`:general`, `:members`, `:security`) using the URL path `/settings`, `/settings/members`, `/settings/security`. The parent LiveView `SettingsLive.Index` handles mount, role checks, and tab routing. Each tab renders as a LiveComponent. This keeps a single LiveView (one WebSocket connection) while enabling bookmarkable tab URLs via `push_patch/2`.

### Role-based visibility enforced in mount and handle_params

On mount, the LiveView loads the current user's `AccountUser` membership to determine their role. In `handle_params/3`, the requested tab is checked against the user's role. If a member tries to access `/settings/members`, they are redirected to `/settings` with a flash message. This is a server-side guard — the tab links are also conditionally rendered in the UI so unauthorized tabs are not shown.

### LiveComponents for each tab section

Each tab is a stateful LiveComponent (`GeneralComponent`, `MembersComponent`, `SecurityComponent`, `DangerZoneComponent`). Components receive the account, current user role, and member list as assigns. This isolates form state (e.g., the account name form in General does not interfere with the member role dropdown in Members) and allows targeted re-rendering when a single tab's data changes.

### HMAC key reveal via JS toggle with confirmation

The HMAC key is fetched from the database only when the user clicks "Reveal" — it is not loaded on page mount (the schema has `load_in_query: false`). A JS confirmation dialog warns the user before the key is shown. The revealed key is stored in the component's socket assigns and cleared when navigating away. This prevents accidental exposure in the DOM.

### HMAC key rotation with typed confirmation

Rotating the HMAC key is destructive — it breaks chain verification for all existing audit log entries. The rotate button opens a modal requiring the user to type "ROTATE" to confirm. On confirmation, a new 32-byte key is generated via `:crypto.strong_rand_bytes/32` and the old key is overwritten. The modal includes a prominent warning about the consequences.

### Account deletion with name-typed confirmation

Deleting an account is irreversible. The danger zone shows only for owners. The delete button opens a modal where the user must type the exact account name to enable the confirm button. Deletion removes the account and all associated records (account_users, api_keys cascade). After deletion, the user is redirected to `/dashboard`.

### Sidebar Settings link updated to account-scoped path

The sidebar's Settings link changes from `~p"/users/settings"` to `"#{@account_base}/settings"`. When no account is loaded (e.g., pre-account-selection), the link falls back to the user settings path. This keeps the Settings entry in the same sidebar position (bottom section, `hero-cog-6-tooth` icon).

## Risks / Trade-offs

- [HMAC key rotation is destructive and irreversible] -> The confirmation dialog and typed "ROTATE" input mitigate accidental rotation. A future enhancement could support key versioning (already implemented in the key-rotation-v2 change) to make rotation non-destructive.
- [Account deletion cascades to all data] -> Typed name confirmation reduces accidental deletion. A future enhancement could add a soft-delete with grace period.
- [Role check on every handle_params adds a query] -> The AccountUser lookup is cached in socket assigns after mount. Role checks in `handle_params` use the cached value, so no additional query is needed per tab switch. Re-fetching only happens on mount.
- [Members tab shows a non-functional invite placeholder] -> This sets user expectations for a feature that does not yet exist. The placeholder is clearly labeled as "coming soon" to avoid confusion.
- [No re-authentication for sensitive actions] -> HMAC reveal, rotation, and account deletion use confirmation dialogs but do not require password re-entry. The user is already authenticated, and Phoenix's sudo mode (`GA.Accounts.sudo_mode?/2`) could be integrated in a future iteration for additional security.
