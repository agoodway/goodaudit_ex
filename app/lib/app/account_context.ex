defmodule GA.AccountContext do
  @moduledoc """
  Context module for managing account-scoped operations and user account access.
  """

  alias GA.Accounts
  alias GA.Accounts.{Account, AccountUser, User}

  @doc false
  @spec list_user_accounts(User.t()) :: [{Account.t(), AccountUser.role()}]
  def list_user_accounts(%User{} = user) do
    Accounts.list_user_accounts(user)
  end

  @doc false
  @spec get_account_for_user(User.t(), String.t() | Ecto.UUID.t()) ::
          {:ok, Account.t()} | {:error, :not_found}
  def get_account_for_user(_user, nil), do: {:error, :not_found}

  def get_account_for_user(%User{} = user, account_id) when is_binary(account_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(account_id),
         %Account{} = account <- Accounts.get_account(uuid),
         true <- user_has_access?(user, account) do
      {:ok, account}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc false
  @spec user_has_access?(User.t(), Account.t()) :: boolean()
  def user_has_access?(%User{} = user, %Account{} = account) do
    case Accounts.get_account_user(user, account) do
      nil -> false
      %AccountUser{} -> true
    end
  end

  @doc false
  @spec get_default_account(User.t(), map()) :: {:ok, Account.t()} | {:error, :no_accounts}
  def get_default_account(%User{} = user, session) do
    last_account_id = session["last_account_id"]

    if last_account_id do
      case get_account_for_user(user, last_account_id) do
        {:ok, account} -> {:ok, account}
        {:error, _} -> first_account(user)
      end
    else
      first_account(user)
    end
  end

  defp first_account(user) do
    case list_user_accounts(user) do
      [{account, _role} | _] -> {:ok, account}
      [] -> {:error, :no_accounts}
    end
  end
end
