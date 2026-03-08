alias GA.Accounts
alias GA.Accounts.{Account, AccountUser, ApiKey, User}
alias GA.Repo

seed_user_email = System.get_env("SEED_USER_EMAIL") || "user@example.com"
seed_user_password = System.get_env("SEED_USER_PASSWORD") || "password1234password1234"
seed_account_name = System.get_env("SEED_ACCOUNT_NAME") || "Acme Corp"
seed_account_slug = System.get_env("SEED_ACCOUNT_SLUG") || "acme-corp"
seed_api_key_name = System.get_env("SEED_API_KEY_NAME") || "Local development"
seed_api_key_token = System.get_env("SEED_API_KEY") || "sk_local_development_seed_key_change_me"
now = DateTime.utc_now() |> DateTime.truncate(:second)

{:ok, %{num_rows: hmac_key_column_count}} =
  Repo.query("""
  SELECT 1
  FROM information_schema.columns
  WHERE table_name = 'accounts' AND column_name = 'hmac_key'
  """)

account_hmac_key? = hmac_key_column_count > 0

user =
  case Accounts.get_user_by_email(seed_user_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          email: seed_user_email,
          password: seed_user_password
        })

      user

    %User{} = user ->
      unless Accounts.get_user_by_email_and_password(seed_user_email, seed_user_password) do
        {:ok, _updated_user} =
          Accounts.update_user_password(user, %{password: seed_user_password})
      end

      Accounts.get_user!(user.id)
  end

user =
  if user.confirmed_at do
    user
  else
    user
    |> User.confirm_changeset()
    |> Repo.update!()
  end

account =
  case Accounts.get_account_by_slug(seed_account_slug) do
    nil ->
      account_changeset =
        %Account{}
        |> Account.changeset(%{name: seed_account_name, slug: seed_account_slug, status: :active})

      account_changeset =
        if account_hmac_key? do
          Ecto.Changeset.put_change(account_changeset, :hmac_key, :crypto.strong_rand_bytes(32))
        else
          account_changeset
        end

      account = Repo.insert!(account_changeset)

      account

    %Account{} = account ->
      account
      |> Account.changeset(%{name: seed_account_name, slug: seed_account_slug, status: :active})
      |> Repo.update!()
  end

account_user =
  case Accounts.get_account_user(user, account) do
    nil ->
      {:ok, account_user} =
        Accounts.create_account_user(%{user_id: user.id, account_id: account.id, role: :owner})

      account_user

    %AccountUser{} = account_user ->
      account_user
      |> AccountUser.changeset(%{user_id: user.id, account_id: account.id, role: :owner})
      |> Repo.update!()
  end

seed_api_key_hash = ApiKey.hash_token(seed_api_key_token)
seed_api_key_prefix = String.slice(seed_api_key_token, 0, 12)

api_key =
  Repo.get_by(ApiKey, token_hash: seed_api_key_hash) ||
    Repo.get_by(ApiKey, account_user_id: account_user.id, name: seed_api_key_name)

api_key =
  case api_key do
    nil ->
      %ApiKey{}
      |> ApiKey.changeset(%{
        name: seed_api_key_name,
        type: :private,
        account_user_id: account_user.id
      })
      |> Ecto.Changeset.put_change(:token_prefix, seed_api_key_prefix)
      |> Ecto.Changeset.put_change(:token_hash, seed_api_key_hash)
      |> Ecto.Changeset.put_change(:status, :active)
      |> Ecto.Changeset.put_change(:expires_at, nil)
      |> Repo.insert!()

    %ApiKey{} = api_key ->
      api_key
      |> ApiKey.changeset(%{
        name: seed_api_key_name,
        type: :private,
        account_user_id: account_user.id
      })
      |> Ecto.Changeset.put_change(:token_prefix, seed_api_key_prefix)
      |> Ecto.Changeset.put_change(:token_hash, seed_api_key_hash)
      |> Ecto.Changeset.put_change(:status, :active)
      |> Ecto.Changeset.put_change(:expires_at, nil)
      |> Ecto.Changeset.put_change(:last_used_at, nil)
      |> Repo.update!()
  end

IO.puts("Seeds ready.")
IO.puts("  User: #{user.email} / #{seed_user_password}")
IO.puts("  Account: #{account.name} (#{account.slug})")
IO.puts("  Membership role: #{account_user.role}")
IO.puts("  API key: #{api_key.name} / #{seed_api_key_token}")
IO.puts("  Confirmed at: #{user.confirmed_at || now}")
