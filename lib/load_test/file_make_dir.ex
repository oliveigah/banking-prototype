defmodule Test do
  # elixir -S mix run -e Test.run
  @operations 10_000_000
  def run do
    {time, _} =
      :timer.tc(fn ->
        Enum.each(1..@operations, &File.mkdir_p!("./persist/#{div(&1, 1_000_000)}"))
      end)

    IO.puts("#{div(time, @operations)} μs")
  end
end
