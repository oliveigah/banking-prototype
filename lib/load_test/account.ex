# To run this test
# elixir --erl "+P 5000000" -S mix run -e Account.LoadTest.run
defmodule Account.LoadTest do
  @moduledoc """
    Test module to execute a load test on the Account module

    Premise: 55_000_000 active clients
    Hypothese: Each 30 seconds 5% of the active clients make some kind of financial operation (transfer, deposit, withdraw, debit card, etc)
    Hypothese: Just 10% of the clients make operations earlier than the cache expire time
    Benchmark: Average response time for any request should be lower than 2 seconds
  """

  # 5% of the active clients
  @total_processes 2_750_000
  # The chunks of data that the metrics will be measure
  @interval_size 100_000
  # To achieve the benchmark, and based on the premise and hypotheses, this is the minimal rps throughput of the system
  @minimal_requests_per_sec 50_000
  # Cache hit percentage hypothese
  @cache_hit_percentage 10

  @doc """
  Executes the load test

  To run the test, use the following command:

  elixir --erl "+P 5000000" -S mix run -e Account.LoadTest.run
  """
  def run do
    {:ok, server} = Account.Cache.start()

    interval_count = round(@total_processes / @interval_size)

    Enum.each(0..(interval_count - 1), &run_interval(server, make_interval(&1)))
  end

  defp make_interval(n) do
    start = n * @interval_size
    start..(start + @interval_size - 1)
  end

  defp run_interval(server, interval) do
    {miss_time, _} =
      :timer.tc(fn ->
        interval
        |> Enum.map(&Account.Cache.account_server_process(server, &1))
        |> Enum.each(&Account.Server.deposit(&1, %{amount: 1000}))
      end)

    average_miss_time = miss_time / @interval_size
    requests_per_sec_miss = round(1_000_000 / average_miss_time)

    IO.puts("#{inspect(interval)}: Cache miss time: #{average_miss_time} μs")
    IO.puts("#{inspect(interval)}: Cache miss rq/s: #{requests_per_sec_miss} requests")

    {hit_time, _} =
      :timer.tc(fn ->
        interval
        |> Enum.map(&Account.Cache.account_server_process(server, &1))
        |> Enum.each(&Account.Server.withdraw(&1, %{amount: 1000}))
      end)

    average_hit_time = hit_time / @interval_size
    requests_per_sec_hit = round(1_000_000 / average_hit_time)

    IO.puts("#{inspect(interval)}: Cache hit time: #{average_hit_time} μs")
    IO.puts("#{inspect(interval)}: Cache hit rq/s: #{requests_per_sec_hit} requests")

    average_rps =
      round(
        (requests_per_sec_hit * @cache_hit_percentage +
           requests_per_sec_miss * (100 - @cache_hit_percentage)) /
          100
      )

    IO.puts("#{inspect(interval)}: Average rps: #{average_rps} requests")

    approved = average_rps >= @minimal_requests_per_sec

    IO.puts("#{inspect(interval)}: Approved? #{approved} \n")
  end
end
