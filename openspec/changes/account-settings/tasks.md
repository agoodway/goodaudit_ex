## 1. Context Functions

- [x] 1.1 Add `GA.Accounts.list_account_members/1` — query `account_users` for account, preload `:user`, return list of `%AccountUser{}` with user data, ordered by role then email
- [x] 1.2 Add `GA.Accounts.update_account/2` — accept `%Account{}` and attrs map, apply changeset, update in repo
- [x] 1.3 Add `GA.Accounts.delete_account/1` — accept `%Account{}`, delete from repo (cascades to account_users, api_keys)
- [x] 1.4 Add `GA.Accounts.rotate_hmac_key/1` — accept `%Account{}`, generate new 32-byte key via `:crypto.strong_rand_bytes/32`, update account, return `{:ok, account}`

## 2. Router and Sidebar Wiring

- [x] 2.1 Add `live "/settings", SettingsLive.Index, :general` route under the `:account_scoped` live_session in router
- [x] 2.2 Add `live "/settings/members", SettingsLive.Index, :members` route
- [x] 2.3 Add `live "/settings/security", SettingsLive.Index, :security` route
- [x] 2.4 Update sidebar Settings link in `GAWeb.Layouts.sidebar_content/1` — change href from `~p"/users/settings"` to `"#{@account_base}/settings"`, keep `hero-cog-6-tooth` icon and `:settings` active_nav

## 3. Settings LiveView Shell

- [x] 3.1 Create `lib/app_web/live/settings_live/index.ex` — `SettingsLive.Index` LiveView with `mount/3` that loads current user's `AccountUser` membership and caches role in socket assigns
- [x] 3.2 Implement `handle_params/3` — parse live_action to determine active tab, enforce role-based access (redirect unauthorized tabs to `:general` with flash), assign active tab
- [x] 3.3 Render tabbed navigation bar with conditional tab visibility based on role — General (all roles), Members (owner + admin), Security (owner only)
- [x] 3.4 Render active tab's LiveComponent based on `@active_tab` assign, passing account, role, and relevant data

## 4. General Tab Component

- [x] 4.1 Create `lib/app_web/live/settings_live/general_component.ex` — stateful LiveComponent showing account name form, read-only slug, and account ID
- [x] 4.2 Implement account name edit form with `phx-change` validation and `phx-submit` handler that calls `GA.Accounts.update_account/2`
- [x] 4.3 Show success flash on save, update parent assigns with new account data
- [x] 4.4 Display account ID in a copyable mono-spaced field for reference

## 5. Members Tab Component

- [x] 5.1 Create `lib/app_web/live/settings_live/members_component.ex` — stateful LiveComponent listing account members
- [x] 5.2 Render members table with columns: email, role badge (owner/admin/member with DaisyUI badge colors), joined date
- [x] 5.3 For owners: render role change dropdown (admin/member) on non-owner rows, wire to `GA.Accounts.update_account_user_role/2`
- [x] 5.4 For owners: render remove member button with confirmation dialog, wire to `GA.Accounts.remove_user_from_account/2`, prevent self-removal
- [x] 5.5 For admins: render members table as read-only (no role change or remove controls)
- [x] 5.6 Render invite placeholder section with "Coming soon" label and disabled invite button

## 6. Security Tab Component

- [x] 6.1 Create `lib/app_web/live/settings_live/security_component.ex` — stateful LiveComponent for HMAC key and account status
- [x] 6.2 Display masked HMAC key (`hmac_••••••••`) by default — do not load actual key on mount
- [x] 6.3 Implement "Reveal" button that calls `GA.Accounts.get_hmac_key/1`, stores in component assigns, renders full key with copy button
- [x] 6.4 Implement "Rotate Key" button that opens modal with warning text and "ROTATE" typed confirmation input
- [x] 6.5 On rotation confirmation, call `GA.Accounts.rotate_hmac_key/1`, show success flash, re-mask key display
- [x] 6.6 Display account status as read-only badge (active = green, suspended = red)

## 7. Danger Zone Component

- [x] 7.1 Create `lib/app_web/live/settings_live/danger_zone_component.ex` — stateful LiveComponent rendered only when role is `:owner`
- [x] 7.2 Render visually distinct danger section with red border and warning copy
- [x] 7.3 Implement "Delete Account" button that opens modal with account name typed confirmation
- [x] 7.4 Enable confirm button only when typed name matches `@account.name` exactly
- [x] 7.5 On deletion confirmation, call `GA.Accounts.delete_account/1`, redirect to `/dashboard` with flash

## 8. Tests

- [x] 8.1 Test `GA.Accounts.list_account_members/1` — returns members with preloaded users, correct ordering
- [x] 8.2 Test `GA.Accounts.update_account/2` — valid update, invalid attrs, slug re-derivation
- [x] 8.3 Test `GA.Accounts.delete_account/1` — cascades to account_users and api_keys
- [x] 8.4 Test `GA.Accounts.rotate_hmac_key/1` — new key differs from old, key is 32 bytes
- [x] 8.5 Test settings LiveView mount — loads account and role correctly
- [x] 8.6 Test role-based tab access — owner sees all tabs, admin sees General + Members, member sees General only
- [x] 8.7 Test role-based redirect — member accessing `/settings/members` redirects to `/settings`
- [x] 8.8 Test General tab — account name update, validation errors, slug display
- [x] 8.9 Test Members tab — member list renders, role change (owner), remove member (owner), read-only for admin
- [x] 8.10 Test Security tab — HMAC key reveal, HMAC key rotation with confirmation, account status display
- [x] 8.11 Test Danger Zone — delete account with correct name confirmation, reject incorrect name, only visible to owners
- [x] 8.12 Test sidebar Settings link points to account-scoped `/settings` route
