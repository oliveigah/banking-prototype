defmodule Account.System do
  def start_link() do
    Supervisor.start_link(
      [Account.ProcessRegistry, Account.Database, Account.Cache],
      strategy: :one_for_one
    )
  end
end
