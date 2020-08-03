defmodule Account.LoadTest do
  @moduledoc """
    Test module to execute a load test on the Account module

    - Premise: 25_000_000 active clients
    - Hypothese 1: Each client make 5 financial operations per day => 125_000_000 operations per day
    - Hypothese 2: The operations are distributed in a normal fashion, 80% of the operations happens in 20% of the time => 125M * 0.8 / (24 * 60 * 60 * 0.2) ≈ 6_000 rps
    - Hypothese 3: Just 10% of the clients make a new operation earlier than the cache expire time (240 seconds)

    Due to techincal limitations on the database module that is currentlly implemented using binary data parse and disk write, the hypothesis can not be tested with data persistance because the persistance module has an average throughput of 1.5k writes/sec
  """

  @total_processes 500_000
  @minimal_requests_per_sec 2_000
  @cache_hit_percentage 10
  @interval_size 25_000

  @doc """
  Executes the load test

  To run the test, use the following command:

  elixir --erl "+P 1000000" -S mix run -e Account.LoadTest.run
  """
  def run do
    Account.System.start_link()

    interval_count = round(@total_processes / @interval_size)

    Enum.each(0..(interval_count - 1), &run_interval(make_interval(&1)))
  end

  defp make_interval(n) do
    start = n * @interval_size
    start..(start + @interval_size - 1)
  end

  defp run_interval(interval) do
    {miss_time, _} =
      :timer.tc(fn ->
        interval
        |> Enum.map(&Account.Cache.server_process/1)
        |> Enum.each(&Account.Server.deposit(&1, %{amount: 1000}))
      end)

    average_miss_time = miss_time / @interval_size
    requests_per_sec_miss = round(1_000_000 / average_miss_time)

    IO.puts("#{inspect(interval)}: Cache miss time: #{average_miss_time} μs")
    IO.puts("#{inspect(interval)}: Cache miss rq/s: #{requests_per_sec_miss} requests")

    {hit_time, _} =
      :timer.tc(fn ->
        interval
        |> Enum.map(&Account.Cache.server_process/1)
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
    Process.sleep(1000)
  end
end
