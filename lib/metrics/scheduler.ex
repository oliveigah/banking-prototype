defmodule Metrics.Scheduler do
  use GenServer
  @interval_time_ms :timer.seconds(60)
  def start_link(_arg) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_arg) do
    :timer.send_interval(@interval_time_ms, :start_metrics)
    {:ok, nil}
  end

  def handle_info(:start_metrics, _) do
    Metrics.Collector.start()
    {:noreply, nil}
  end
end
