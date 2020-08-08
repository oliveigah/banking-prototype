defmodule Account.System do
  def start_link() do
    Supervisor.start_link(
      [Account.ProcessRegistry, Database, Metrics.Scheduler, Account.Cache],
      strategy: :one_for_one
    )
  end
end
