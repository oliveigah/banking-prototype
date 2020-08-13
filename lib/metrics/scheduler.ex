defmodule Metrics.Scheduler do
  @moduledoc """
  `GenServer` responsible for start the `Metrics.Collector` task every 5 minutes
  """
  use GenServer
  @interval_time_ms :timer.seconds(300)
  @doc false
  def start_link(_arg) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Initialize the server and schedules the message to be send every 5 minutes
  """
  def init(_arg) do
    :timer.send_interval(@interval_time_ms, :start_metrics)
    {:ok, nil}
  end

  @doc false
  def handle_info(:start_metrics, _) do
    Metrics.Collector.start()
    {:noreply, nil}
  end
end
