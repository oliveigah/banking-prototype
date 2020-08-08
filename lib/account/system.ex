defmodule Account.System do
  def start_link() do
    Supervisor.start_link(
      [
        Account.ProcessRegistry,
        Account.Cache,
        Http.Account
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end
end
