## ADDED Requirements

### Requirement: Settings route and sidebar wiring

The dashboard MUST include a `/dashboard/accounts/:account_id/settings` route that renders `SettingsLive.Index`. The sidebar "Settings" link MUST point to this account-scoped route instead of `/users/settings`. The route MUST be inside the `:account_scoped` live_session so that `@current_account`, `@current_user`, and `@current_scope` assigns are available.

#### Scenario: Settings route resolves
- **WHEN** a logged-in user navigates to `/dashboard/accounts/:account_id/settings`
- **THEN** the `SettingsLive.Index` LiveView renders with the General tab active

#### Scenario: Tab routes resolve
- **WHEN** a logged-in owner navigates to `/dashboard/accounts/:account_id/settings/members`
- **THEN** the `SettingsLive.Index` LiveView renders with the Members tab active

#### Scenario: Sidebar link points to account settings
- **WHEN** the dashboard sidebar renders for an account
- **THEN** the Settings link href is `/dashboard/accounts/:account_id/settings`

### Requirement: Role-based tab access

The settings LiveView MUST enforce role-based visibility. Owners see all tabs (General, Members, Security) and the Danger Zone. Admins see General and Members (with role management as read-only). Members see General only. Attempting to access a restricted tab MUST redirect to the General tab with an info flash message.

#### Scenario: Owner sees all tabs
- **WHEN** an owner navigates to `/settings`
- **THEN** the tab bar shows General, Members, and Security tabs
- **THEN** the Danger Zone section is visible below the active tab

#### Scenario: Admin sees General and Members
- **WHEN** an admin navigates to `/settings`
- **THEN** the tab bar shows General and Members tabs
- **THEN** the Security tab and Danger Zone are not visible

#### Scenario: Member sees General only
- **WHEN** a member navigates to `/settings`
- **THEN** the tab bar shows only the General tab
- **THEN** the Members tab, Security tab, and Danger Zone are not visible

#### Scenario: Member redirected from Members tab
- **WHEN** a member navigates to `/settings/members`
- **THEN** they are redirected to `/settings`
- **THEN** an info flash message is displayed

#### Scenario: Admin redirected from Security tab
- **WHEN** an admin navigates to `/settings/security`
- **THEN** they are redirected to `/settings`
- **THEN** an info flash message is displayed

### Requirement: General tab — edit account name

The General tab MUST display the account name in an editable text input, the slug as a read-only field, and the account ID as a copyable reference. Submitting the name form MUST call `GA.Accounts.update_account/2` and update the account. The slug MUST be re-derived from the new name on save.

#### Scenario: Account name displayed
- **WHEN** the General tab renders
- **THEN** the account name is shown in an editable text input
- **THEN** the slug is shown as a read-only field
- **THEN** the account ID is shown in a mono-spaced copyable field

#### Scenario: Account name updated successfully
- **WHEN** the user changes the account name to "New Name" and submits the form
- **THEN** `GA.Accounts.update_account/2` is called with the new name
- **THEN** the account name updates to "New Name"
- **THEN** the slug updates to "new-name"
- **THEN** a success flash message is displayed

#### Scenario: Account name validation error
- **WHEN** the user clears the account name field and submits the form
- **THEN** a validation error is shown indicating the name is required
- **THEN** the account is not updated

### Requirement: Members tab — list and manage members

The Members tab MUST display a table of all account members with their email, role (as a DaisyUI badge), and join date. Owners MUST be able to change member roles (between admin and member) and remove members. Admins MUST see the table as read-only. The tab MUST include a non-functional invite placeholder.

#### Scenario: Members table renders
- **WHEN** the Members tab renders for an owner or admin
- **THEN** a table shows all account members with columns: email, role badge, joined date
- **THEN** members are ordered by role (owner first) then email

#### Scenario: Owner changes member role
- **WHEN** an owner selects "admin" from the role dropdown on a member row
- **THEN** `GA.Accounts.update_account_user_role/2` is called
- **THEN** the member's role badge updates to "admin"
- **THEN** a success flash message is displayed

#### Scenario: Owner cannot change own role
- **WHEN** the owner views their own row in the members table
- **THEN** the role dropdown is not shown (or is disabled) for the owner row

#### Scenario: Owner removes member
- **WHEN** an owner clicks the remove button on a member row and confirms
- **THEN** `GA.Accounts.remove_user_from_account/2` is called
- **THEN** the member is removed from the table
- **THEN** a success flash message is displayed

#### Scenario: Owner cannot remove self
- **WHEN** the owner views their own row in the members table
- **THEN** the remove button is not shown for the owner row

#### Scenario: Admin sees read-only members
- **WHEN** an admin views the Members tab
- **THEN** the members table renders without role change dropdowns or remove buttons

#### Scenario: Invite placeholder displayed
- **WHEN** the Members tab renders
- **THEN** an invite section is shown with a "Coming soon" label and a disabled invite button

### Requirement: Security tab — HMAC key management

The Security tab MUST display the HMAC key masked by default. A "Reveal" button MUST fetch and display the full key after confirmation. A "Rotate Key" button MUST generate a new HMAC key after the user types "ROTATE" to confirm. The account status MUST be displayed as a read-only badge.

#### Scenario: HMAC key displayed masked
- **WHEN** the Security tab renders
- **THEN** the HMAC key is shown as a masked value (e.g., `hmac_••••••••`)
- **THEN** the actual key is not loaded from the database

#### Scenario: HMAC key revealed
- **WHEN** the owner clicks the "Reveal" button and confirms
- **THEN** `GA.Accounts.get_hmac_key/1` is called
- **THEN** the full HMAC key is displayed with a copy button
- **THEN** the "Reveal" button changes to a "Hide" button

#### Scenario: HMAC key hidden after reveal
- **WHEN** the owner clicks the "Hide" button after revealing the key
- **THEN** the key returns to its masked state
- **THEN** the key value is cleared from the component assigns

#### Scenario: HMAC key rotation with confirmation
- **WHEN** the owner clicks "Rotate Key"
- **THEN** a modal opens with a warning that rotation breaks chain verification of existing entries
- **THEN** the modal contains a text input requiring the user to type "ROTATE"
- **THEN** the confirm button is disabled until "ROTATE" is typed

#### Scenario: HMAC key rotated successfully
- **WHEN** the owner types "ROTATE" and clicks confirm in the rotation modal
- **THEN** `GA.Accounts.rotate_hmac_key/1` is called
- **THEN** a success flash message is displayed
- **THEN** the HMAC key display returns to masked state

#### Scenario: Account status displayed
- **WHEN** the Security tab renders
- **THEN** the account status is shown as a read-only badge
- **THEN** an active status shows as a green badge
- **THEN** a suspended status shows as a red badge

### Requirement: Danger Zone — delete account

The Danger Zone MUST be visible only to account owners. It MUST contain a "Delete Account" button that opens a confirmation modal requiring the user to type the exact account name. Account deletion MUST remove the account and redirect to `/dashboard`.

#### Scenario: Danger Zone visible to owner
- **WHEN** an owner views the settings page
- **THEN** a Danger Zone section is rendered with a red border and warning text
- **THEN** a "Delete Account" button is shown

#### Scenario: Danger Zone hidden from non-owners
- **WHEN** an admin or member views the settings page
- **THEN** the Danger Zone section is not rendered

#### Scenario: Delete account modal
- **WHEN** the owner clicks "Delete Account"
- **THEN** a modal opens explaining that deletion is permanent
- **THEN** the modal shows the account name and asks the user to type it to confirm
- **THEN** the confirm button is disabled until the typed name matches exactly

#### Scenario: Account deleted successfully
- **WHEN** the owner types the correct account name and clicks confirm
- **THEN** `GA.Accounts.delete_account/1` is called
- **THEN** the user is redirected to `/dashboard`
- **THEN** a success flash message is displayed

#### Scenario: Delete rejected on name mismatch
- **WHEN** the owner types an incorrect account name in the delete modal
- **THEN** the confirm button remains disabled
- **THEN** the account is not deleted

### Requirement: Context function — list_account_members

`GA.Accounts.list_account_members/1` MUST accept an `%Account{}` and return a list of `%AccountUser{}` structs with the `:user` association preloaded, ordered by role (owner first, then admin, then member) and then by user email.

#### Scenario: List members for account
- **WHEN** `GA.Accounts.list_account_members(account)` is called
- **THEN** it returns all `AccountUser` records for that account with `:user` preloaded
- **THEN** results are ordered by role priority (owner, admin, member) then by email

#### Scenario: Empty account
- **WHEN** `GA.Accounts.list_account_members(account)` is called for an account with no members
- **THEN** it returns an empty list

### Requirement: Context function — update_account

`GA.Accounts.update_account/2` MUST accept an `%Account{}` and an attrs map, apply `Account.changeset/2`, and persist the update. The slug MUST be re-derived from the name if the name changes.

#### Scenario: Successful update
- **WHEN** `GA.Accounts.update_account(account, %{name: "New Name"})` is called
- **THEN** it returns `{:ok, %Account{name: "New Name", slug: "new-name"}}`

#### Scenario: Invalid update
- **WHEN** `GA.Accounts.update_account(account, %{name: ""})` is called
- **THEN** it returns `{:error, %Ecto.Changeset{}}` with a validation error on `:name`

### Requirement: Context function — delete_account

`GA.Accounts.delete_account/1` MUST accept an `%Account{}` and delete it from the database. Associated `account_users` and `api_keys` MUST be removed via cascade.

#### Scenario: Successful deletion
- **WHEN** `GA.Accounts.delete_account(account)` is called
- **THEN** the account is deleted
- **THEN** all associated `AccountUser` records are deleted
- **THEN** all associated `ApiKey` records are deleted

### Requirement: Context function — rotate_hmac_key

`GA.Accounts.rotate_hmac_key/1` MUST accept an `%Account{}`, generate a new 32-byte HMAC key via `:crypto.strong_rand_bytes/32`, and update the account's `hmac_key` field.

#### Scenario: Successful rotation
- **WHEN** `GA.Accounts.rotate_hmac_key(account)` is called
- **THEN** it returns `{:ok, %Account{}}` with a new `hmac_key`
- **THEN** the new key is 32 bytes
- **THEN** the new key differs from the previous key
