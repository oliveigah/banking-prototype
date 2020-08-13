defmodule Database.LoadTest do
  @moduledoc false

  @seconds_to_measure 10
  @doc """
  Executes the load test

  To run the test, use the following command:

  elixir -S mix run -e Database.LoadTest.run
  """
  def run do
    Account.System.start_link()

    run_write_test()
    |> run_read_test()

    File.rm_rf("./persist")
  end

  def run_write_test do
    init_time = Time.utc_now()

    try do
      Enum.each(1..100_000_000, &loop_write(&1, init_time))
    catch
      index ->
        operations_per_sec = round(index / @seconds_to_measure)
        IO.puts("Writes per second: #{operations_per_sec}")
        seconds_per_operation = round(@seconds_to_measure * 1000000 / index)
        IO.puts("Average write time: #{seconds_per_operation} μs")
        index
    end
  end

  defp loop_write(index, init_time) do
    if(Time.diff(Time.utc_now(), init_time) >= @seconds_to_measure) do
      throw(index)
    end

    Database.store_sync(index, Account.new(), "accounts")
  end

  def run_read_test(max_index) do
    init_time = Time.utc_now()

    try do
      loop_read(1, max_index, init_time, 0)
    catch
      {index, cycle} ->
        total_reads = index + cycle * max_index
        operations_per_sec = round(total_reads / @seconds_to_measure)
        IO.puts("Reads per second: #{operations_per_sec}")
        seconds_per_operation = round(@seconds_to_measure * 1000000 / total_reads)
        IO.puts("Average read time: #{seconds_per_operation} μs")
    end
  end

  defp loop_read(index, max_index, init_time, cycle) do
    if(Time.diff(Time.utc_now(), init_time) >= @seconds_to_measure) do
      throw({index, cycle})
    end

    Database.get(index, "accounts")
    new_index = rem(index, max_index) + 1
    new_cycle = cycle + div(index, max_index)

    loop_read(new_index, max_index, init_time, new_cycle)
  end
end
