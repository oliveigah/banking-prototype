defmodule Account.Exchange do
  use GenServer

  @currency_rate_list [
    USD: 1,
    EUR: 0.85,
    BRL: 5.45,
    GBP: 0.77
  ]

  def init(_) do
    :ets.new(
      __MODULE__,
      [:named_table, read_concurrency: true]
    )

    Enum.each(@currency_rate_list, &put/1)

    {:ok, nil}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  defp put({currency, rate}) do
    :ets.insert(__MODULE__, {currency, rate})
  end

  defp get!(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> raise(Account.Exchange.CurrencyError)
    end
  end

  def convert(current_currency, amount, new_currency) do
    current_rate = get!(current_currency)
    new_rate = get!(new_currency)
    exchange_rate = current_rate / new_rate
    amount / exchange_rate
  end

  defmodule CurrencyError do
    defexception message: "Invalid currency"
  end
end
