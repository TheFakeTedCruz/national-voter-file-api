defmodule NationalVoterFile.TokenControllerTest do
  use NationalVoterFile.ApiCase, resource_name: :token

  defp create_payload(email, password) do
    %{
      "username" => email,
      "password" => password
    }
  end

  describe "create" do
    test "authenticates and returns JWT and user ID when data is valid", %{conn: conn} do
      user = build(:user, %{password: "password"}) |> set_password("password") |> insert
      conn = post conn, token_path(conn, :create), create_payload(user.email, user.password)

      user_id = user.id
      response = json_response(conn, 201)
      assert response["token"]
      assert response["user_id"] == user_id
    end

    test "does not authenticate and renders errors when the email and password are missing", %{conn: conn} do
      conn = post conn, token_path(conn, :create), %{"username" => ""}

      response = json_response(conn, 401)
      [error | _] = response["errors"]
      assert error["detail"] == "Please enter your email and password."
      assert renders_401_unauthorized?(error)
      refute response["token"]
      refute response["user_id"]
    end

    test "does not authenticate and renders errors when only the password is missing", %{conn: conn} do
      conn = post conn, token_path(conn, :create), %{"username" => "test@email.com"}

      response = json_response(conn, 401)
      [error | _] = response["errors"]
      assert error["detail"] == "Please enter your password."
      assert renders_401_unauthorized?(error)
      refute response["token"]
      refute response["user_id"]
    end

    test "does not authenticate and renders errors when the password is wrong", %{conn: conn} do
      user = build(:user, %{password: "password"}) |> set_password("password") |> insert
      conn = post conn, token_path(conn, :create), create_payload(user.email, "wrong password")

      response = json_response(conn, 401)
      [error | _] = response["errors"]
      assert error["detail"] == "Check your email and password and try again."
      assert renders_401_unauthorized?(error)
      refute response["token"]
      refute response["user_id"]
    end

    test "does not authenticate and renders errors when the user doesn't exist", %{conn: conn} do
      conn = post conn, token_path(conn, :create), create_payload("notauser@test.com", "password")

      response = json_response(conn, 401)
      [error | _] = response["errors"]
      assert error["detail"] == "Check your email and password and try again."
      assert renders_401_unauthorized?(error)
      refute response["token"]
      refute response["user_id"]
    end
  end

  describe "refresh" do
    test "refreshes JWT and returns JWT and user ID when data is valid", %{conn: conn} do
      user = build(:user, %{password: "password"}) |> set_password("password") |> insert
      {:ok, token, _claims} = user |> Guardian.encode_and_sign(:token)

      conn = post conn, token_path(conn, :refresh), %{token: token}

      response = json_response(conn, 201)
      assert response["token"]
      assert response["user_id"] == user.id
    end

    test "does not authenticate and renders errors when the token is expired", %{conn: conn} do
      user = build(:user, %{password: "password"}) |> set_password("password") |> insert
      {:ok, token, _claims} = user |> Guardian.encode_and_sign(:token, %{ "exp" => Guardian.Utils.timestamp - 10})

      conn = post conn, token_path(conn, :refresh), %{token: token}

      response = json_response(conn, 401)
      refute response["token"]
      refute response["user_id"]
      [error | _] = response["errors"]
      assert renders_401_unauthorized?(error)
      assert error["detail"] == "token_expired"
    end
  end

  defp renders_401_unauthorized?(%{"id" => "UNAUTHORIZED", "title" => "401 Unauthorized", "status" => 401}), do: true
  defp renders_401_unauthorized?(_), do: false
end
