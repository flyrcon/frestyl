ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Frestyl.Repo, :manual)


# Ensure support files are loaded before running tests
Enum.each(Path.wildcard(Path.expand("support/**/*.ex", __DIR__)), &Code.require_file/1)
