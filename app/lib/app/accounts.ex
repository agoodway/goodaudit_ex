defmodule GA.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias GA.Repo

  alias GA.Accounts.{Account, AccountUser, ApiKey, User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `GA.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `GA.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  # ============================================
  # Account Functions
  # ============================================

  @doc "Get an account by ID."
  def get_account(id), do: Repo.get(Account, id)

  @doc "Get an account by slug."
  def get_account_by_slug(slug), do: Repo.get_by(Account, slug: slug)

  @doc "Create a new account with the given user as owner."
  def create_account(user, attrs) do
    Repo.transaction(fn ->
      with {:ok, account} <- attrs |> account_changeset_with_hmac_key() |> Repo.insert(),
           {:ok, _account_user} <- add_user_to_account(account, user, :owner) do
        account
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Lists all accounts a user has access to, with their role.
  Returns [{account, role}] sorted by account name.
  """
  def list_user_accounts(%User{} = user) do
    AccountUser
    |> where([au], au.user_id == ^user.id)
    |> join(:inner, [au], a in Account, on: au.account_id == a.id)
    |> where([au, a], a.status == :active)
    |> select([au, a], {a, au.role})
    |> order_by([au, a], asc: a.name)
    |> Repo.all()
  end

  @doc "Creates an account."
  def create_account(attrs) when is_map(attrs) do
    attrs
    |> account_changeset_with_hmac_key()
    |> Repo.insert()
  end

  @doc "Fetches only the hmac key for an account."
  def get_hmac_key(account_id) when is_binary(account_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(account_id),
         hmac_key when not is_nil(hmac_key) <- fetch_hmac_key(uuid) do
      {:ok, hmac_key}
    else
      :error -> {:error, :invalid_id}
      nil -> {:error, :not_found}
    end
  end

  def get_hmac_key(_), do: {:error, :invalid_id}

  defp fetch_hmac_key(account_id) do
    query =
      from(a in Account,
        where: a.id == ^account_id,
        select: a.hmac_key
      )

    Repo.one(query)
  end

  @doc "Creates an account user membership."
  def create_account_user(attrs) when is_map(attrs) do
    %AccountUser{}
    |> AccountUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update an account's attributes. Re-derives slug when name changes."
  def update_account(%Account{} = account, attrs) do
    changeset =
      account
      |> Account.changeset(attrs)
      |> maybe_rederive_slug()

    Repo.update(changeset)
  end

  @doc "Delete an account. Cascades to account_users and api_keys."
  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end

  @doc "Rotate the HMAC key for an account. Generates a new 32-byte key."
  def rotate_hmac_key(%Account{} = account) do
    account
    |> Ecto.Changeset.change(hmac_key: :crypto.strong_rand_bytes(32))
    |> Repo.update()
  end

  @doc "List all members of an account with preloaded users, ordered by role then email."
  def list_account_members(%Account{} = account) do
    role_order = dynamic([au], fragment("CASE ? WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END", au.role))

    AccountUser
    |> where([au], au.account_id == ^account.id)
    |> preload(:user)
    |> order_by([au], ^role_order)
    |> order_by([au], asc: fragment("(SELECT email FROM users WHERE id = ?)", au.user_id))
    |> Repo.all()
  end

  defp maybe_rederive_slug(changeset) do
    case Ecto.Changeset.get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        Ecto.Changeset.put_change(changeset, :slug, slug)
    end
  end

  # ============================================
  # AccountUser (Membership) Functions
  # ============================================

  @doc "Get a user's membership in an account."
  def get_account_user(user, account) do
    Repo.get_by(AccountUser, user_id: user.id, account_id: account.id)
  end

  @doc "Get account_user by ID with preloads."
  def get_account_user!(id) do
    AccountUser
    |> Repo.get!(id)
    |> Repo.preload([:user, :account])
  end

  @doc "Add a user to an account with a role."
  def add_user_to_account(account, user, role \\ :member) do
    %AccountUser{}
    |> AccountUser.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert()
  end

  @doc "Remove a user from an account."
  def remove_user_from_account(account, user) do
    case get_account_user(user, account) do
      nil -> {:error, :not_found}
      account_user -> Repo.delete(account_user)
    end
  end

  @doc "Update a user's role in an account."
  def update_account_user_role(account_user, role) do
    account_user
    |> AccountUser.changeset(%{role: role})
    |> Repo.update()
  end

  # ============================================
  # API Key Functions
  # ============================================

  @doc "Counts active (non-revoked, non-expired) API keys for an account."
  def count_active_api_keys(account_id) when is_binary(account_id) do
    now = DateTime.utc_now()

    from(k in ApiKey,
      join: au in AccountUser,
      on: k.account_user_id == au.id,
      where: au.account_id == ^account_id,
      where: k.status == :active,
      where: is_nil(k.expires_at) or k.expires_at > ^now,
      select: count(k.id)
    )
    |> Repo.one()
  end

  def count_active_api_keys(_), do: 0

  @doc "Verify an API token and return the key with account_user preloaded."
  def verify_api_token(token) do
    prefix = String.slice(token, 0, 12)
    hash = ApiKey.hash_token(token)

    query =
      from(k in ApiKey,
        where: k.token_prefix == ^prefix and k.token_hash == ^hash,
        where: k.status == :active,
        where: is_nil(k.expires_at) or k.expires_at > ^DateTime.utc_now(),
        preload: [account_user: [:user, :account]]
      )

    case Repo.one(query) do
      nil -> {:error, :invalid_token}
      api_key -> {:ok, api_key}
    end
  end

  @doc "Update last_used_at timestamp."
  def touch_api_key(api_key) do
    api_key
    |> Ecto.Changeset.change(last_used_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @doc "Create a new API key for an account_user (membership)."
  def create_api_key(account_user, attrs) do
    type = attrs[:type] || :public
    token = ApiKey.generate_token(type)
    prefix = String.slice(token, 0, 12)
    hash = ApiKey.hash_token(token)

    changeset =
      %ApiKey{account_user_id: account_user.id}
      |> ApiKey.changeset(Map.put(attrs, :account_user_id, account_user.id))
      |> Ecto.Changeset.put_change(:token_prefix, prefix)
      |> Ecto.Changeset.put_change(:token_hash, hash)

    case Repo.insert(changeset) do
      {:ok, api_key} -> {:ok, {api_key, token}}
      error -> error
    end
  end

  @doc "List API keys for an account_user."
  def list_api_keys(account_user) do
    from(k in ApiKey, where: k.account_user_id == ^account_user.id)
    |> Repo.all()
  end

  @doc "Revoke an API key."
  def revoke_api_key(api_key) do
    api_key
    |> Ecto.Changeset.change(status: :revoked)
    |> Repo.update()
  end

  defp account_changeset_with_hmac_key(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Ecto.Changeset.put_change(:hmac_key, :crypto.strong_rand_bytes(32))
  end
end
