defmodule Banking.System do
  @moduledoc false
  def start_link() do
    Supervisor.start_link(
      [Database, Account.System, Metrics.System],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
