# GA

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Seeded development data

Running `mix ecto.reset` or `mix run priv/repo/seeds.exs` creates idempotent development seed data:

* User: `user@example.com`
* Password: `password1234password1234`
* Account: `Acme Corp` (`acme-corp`)
* API key: `sk_local_development_seed_key_change_me`

You can override the seeded values with these environment variables before running the seeds:

* `SEED_USER_EMAIL`
* `SEED_USER_PASSWORD`
* `SEED_ACCOUNT_NAME`
* `SEED_ACCOUNT_SLUG`
* `SEED_API_KEY_NAME`
* `SEED_API_KEY`

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
