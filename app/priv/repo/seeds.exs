alias GA.Accounts
alias GA.Repo

# Create test user
{:ok, user} =
  Accounts.register_user(%{
    email: "user@example.com",
    password: "password1234password1234"
  })

# Confirm the user (skip email confirmation)
user
|> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
|> Repo.update!()

# Create two accounts
{:ok, account1} = Accounts.create_account(%{name: "Acme Corp"})
{:ok, account2} = Accounts.create_account(%{name: "Globex Industries"})

# Link user to both accounts
{:ok, _} =
  Accounts.create_account_user(%{user_id: user.id, account_id: account1.id, role: :owner})

{:ok, _} =
  Accounts.create_account_user(%{user_id: user.id, account_id: account2.id, role: :member})

IO.puts("Seeds created successfully!")
IO.puts("  User: user@example.com / password1234password1234")
IO.puts("  Accounts: Acme Corp (owner), Globex Industries (member)")
