defmodule GAWeb.Api.V1.TaxonomyControllerTest do
  use GAWeb.ConnCase, async: false

  import GA.AccountsFixtures

  alias GA.Accounts

  describe "GET /api/v1/taxonomies" do
    test "returns framework taxonomy summaries with read access", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/taxonomies")
        |> json_response(200)

      frameworks = Enum.map(response["data"], & &1["framework"])
      assert frameworks == ["gdpr", "hipaa", "iso_27001", "pci_dss", "soc2"]
      assert Enum.all?(response["data"], &(&1["version"] == "1.0.0"))
    end

    test "returns 401 without auth", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/taxonomies")
      |> json_response(401)
    end
  end

  describe "GET /api/v1/taxonomies/:framework" do
    test "returns framework taxonomy tree", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/taxonomies/hipaa")
        |> json_response(200)

      assert response["data"]["framework"] == "hipaa"
      assert response["data"]["version"] == "1.0.0"
      assert is_map(response["data"]["taxonomy"])
      assert Map.has_key?(response["data"]["taxonomy"], "access")
    end

    test "returns 404 for unknown framework", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/taxonomies/unknown")
        |> json_response(404)

      assert response["status"] == 404
      assert response["message"] == "Unknown framework: unknown"
    end
  end

  defp account_api_context(user \\ nil) do
    user = user || user_fixture()

    {:ok, account} =
      Accounts.create_account(%{name: "Taxonomy API Account #{System.unique_integer([:positive])}"})

    {:ok, account_user} = Accounts.add_user_to_account(account, user, :owner)

    {:ok, {_public_key, public_token}} =
      Accounts.create_api_key(account_user, %{name: "Public Key", type: :public})

    {:ok, {_private_key, private_token}} =
      Accounts.create_api_key(account_user, %{name: "Private Key", type: :private})

    %{
      account: account,
      user: user,
      public_token: public_token,
      private_token: private_token
    }
  end

  defp api_key_conn(conn, token) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{token}")
  end
end
