defmodule GA.Accounts.HmacKeyTest do
  use GA.DataCase

  alias GA.Accounts
  alias GA.Accounts.Account

  import GA.AccountsFixtures

  describe "account hmac keys" do
    test "create_account/2 auto-generates a 32-byte hmac_key" do
      user = user_fixture()

      assert {:ok, account} =
               Accounts.create_account(user, %{name: "Acme #{System.unique_integer([:positive])}"})

      assert is_binary(account.hmac_key)
      assert byte_size(account.hmac_key) == 32
    end

    test "get_hmac_key/1 returns key for a valid account" do
      user = user_fixture()
      {:ok, account} = Accounts.create_account(user, %{name: "Globex #{System.unique_integer()}"})

      assert {:ok, hmac_key} = Accounts.get_hmac_key(account.id)
      assert hmac_key == account.hmac_key
    end

    test "get_hmac_key/1 returns {:error, :not_found} for missing account" do
      assert {:error, :not_found} = Accounts.get_hmac_key(Ecto.UUID.generate())
    end

    test "each account gets a unique key" do
      user = user_fixture()
      {:ok, first} = Accounts.create_account(user, %{name: "Initech #{System.unique_integer()}"})

      {:ok, second} =
        Accounts.create_account(user, %{name: "Initrode #{System.unique_integer()}"})

      assert first.hmac_key != second.hmac_key
    end

    test "account inspect output omits hmac_key" do
      user = user_fixture()

      {:ok, account} =
        Accounts.create_account(user, %{name: "Umbrella #{System.unique_integer()}"})

      inspected = inspect(account)

      refute inspected =~ "hmac_key"
      refute inspected =~ Base.encode16(account.hmac_key)
    end

    test "changeset ignores externally supplied hmac_key" do
      external_key = :crypto.strong_rand_bytes(32)

      changeset =
        Account.changeset(%Account{}, %{
          "name" => "Stark Industries",
          "hmac_key" => external_key
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :hmac_key)
    end
  end
end
