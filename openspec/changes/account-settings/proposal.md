## Why

GoodAudit's dashboard has a "Settings" link in the sidebar that currently points to the global user settings page (`/users/settings`). There is no account-level settings experience — owners and admins have no way to rename their account, manage team members and roles, view or rotate HMAC keys, or delete the account without direct database access or API calls. This forces account administration through non-obvious paths and makes it impossible for non-technical users to manage their organization. An account settings LiveView gives account stakeholders direct control over their account configuration, team membership, and security posture from the dashboard.

## What Changes

1. **Account settings LiveView** — A new LiveView at `/dashboard/accounts/:account_id/settings` with a tabbed interface. The sidebar "Settings" link is updated to point here instead of `/users/settings`. The view uses the existing `@current_account` and `@current_user` assigns from the `:load_account_context` on_mount hook.

2. **General tab** — Displays the account name in an editable form field, the slug as a read-only derived value, and the account ID for reference. Submitting the form calls `GA.Accounts.Account.changeset/2` and updates the account. The slug is re-derived from the name on save.

3. **Members tab** — Lists all account members with their email, role badge, and join date. Owners can change a member's role (between admin and member) via a dropdown and remove members via a delete button with confirmation. A placeholder section indicates that invite functionality is planned for a future change.

4. **Security tab** — Shows the HMAC key masked by default (e.g., `hmac_••••••••`). A "Reveal" button unmasks the key after a confirmation dialog. A "Rotate Key" button generates a new HMAC key with a strong warning that rotation breaks chain verification of existing entries. Displays the account status (active/suspended) as a read-only badge.

5. **Danger Zone** — A visually distinct section (only visible to owners) with a "Delete Account" button. Deletion requires typing the account name to confirm. On confirmation, the account is deleted and the user is redirected to the dashboard root.

6. **Role-based access control** — The view enforces visibility based on the current user's role: owners see all tabs and the danger zone, admins see General + Members (with roles as read-only), members see General only. Unauthorized tab access redirects to the General tab.

> **Note:** This change does not add member invite functionality — that is deferred to a future change. The Members tab includes a non-functional placeholder for invites.

## Capabilities

### New Capabilities
- `account-settings-general`: Edit account name, view slug and account ID
- `account-settings-members`: List, role-manage, and remove account members
- `account-settings-security`: View/reveal HMAC key, rotate HMAC key, view account status
- `account-settings-danger-zone`: Delete account with typed confirmation

### Modified Capabilities
- None

## Impact

- **New files**: `lib/app_web/live/settings_live/index.ex`, `lib/app_web/live/settings_live/general_component.ex`, `lib/app_web/live/settings_live/members_component.ex`, `lib/app_web/live/settings_live/security_component.ex`, `lib/app_web/live/settings_live/danger_zone_component.ex`
- **Modified file**: `lib/app_web/router.ex` — add `/settings` route under dashboard account scope
- **Modified file**: `lib/app_web/components/layouts.ex` — update sidebar Settings link to account-scoped route
- **Modified file**: `lib/app/accounts.ex` — add `list_account_members/1`, `update_account/2`, `delete_account/1`, `rotate_hmac_key/1` functions
- **New tests**: `test/app_web/live/settings_live_test.exs`
