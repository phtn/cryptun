# Cryptun

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cryptun` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cryptun, "~> 0.1.0"}
  ]
end
```

# Release Build

```zsh
 MIX_ENV=prod mix release
* assembling cryptun-0.1.0 on MIX_ENV=prod
* using config/runtime.exs to configure the release at runtime
* creating _build/prod/rel/cryptun/releases/0.1.0/env.sh
* building /Users/xpriori/Code/elixr/cryptun/_build/prod/cryptun-0.1.0.tar.gz

Release created at _build/prod/rel/cryptun

    # To start your system
    _build/prod/rel/cryptun/bin/cryptun start

Once the release is running:

    # To connect to it remotely
    _build/prod/rel/cryptun/bin/cryptun remote

    # To stop it gracefully (you may also send SIGINT/SIGTERM)
    _build/prod/rel/cryptun/bin/cryptun stop

To list all commands:

    _build/prod/rel/cryptun/bin/cryptun

```


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/cryptun>.

