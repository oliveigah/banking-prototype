defmodule Metrics.Collector do
  @database_folder "metrics"

  def start() do
    Task.start(&collect_metrics/0)
  end

  def collect_metrics() do
    IO.puts("Collecting system's metrics...")
    metric_key = compose_metric_key()
    new_metric = compose_metrics_data()
    current_metrics = Database.get(metric_key, @database_folder) || %{}
    new_metrics = Map.put(current_metrics, Time.utc_now(), new_metric)
    Database.store_async(metric_key, new_metrics, @database_folder)
  end

  defp compose_metric_key() do
    now = Date.utc_today()
    formatted_month = if now.month < 10, do: "0#{now.month}", else: now.month
    formatted_day = if now.day < 10, do: "0#{now.day}", else: now.day
    "#{now.year}#{formatted_month}#{formatted_day}"
  end

  defp compose_metrics_data() do
    [
      memory_usage: div(:erlang.memory(:total), 1_000_000),
      process_count: :erlang.system_info(:process_count)
    ]
  end
end
