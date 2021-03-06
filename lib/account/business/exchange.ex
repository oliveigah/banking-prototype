defmodule Account.Exchange do
  @moduledoc """
    Module responsible for the currency conversion logic and the maintance of the exchange rates table

    - The exchange rates are updated hourly
    - Only the dollar rates are persisted, all others rates are calculated converting the two currencies to dollars first
  """
  @doc false
  use GenServer
  @update_time_ms :timer.hours(1)

  @currency_rate_list [
    USD: 1,
    EUR: 0.85,
    BRL: 5.45,
    GBP: 0.77
  ]

  @doc """
  Initialize the module, creating an ETS table and running a server that will update it hourly

  - Since the ETS table is created inside this server, if for whatever reason the rate update fails, all exchange operations will be unavaiable until the ETS table is up to date
  """
  def init(_) do
    :ets.new(
      __MODULE__,
      [:named_table, read_concurrency: true]
    )

    update_rates(@currency_rate_list)

    :timer.send_interval(@update_time_ms, :update_exchange_rates)

    {:ok, nil}
  end

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc false
  def handle_info(:update_exchange_rates, _) do
    update_rates(@currency_rate_list)
    {:noreply, nil}
  end

  defp handle_initial_zeros(value) do
    if value < 10, do: "0#{value}", else: value
  end

  defp compose_exchange_key() do
    now = DateTime.utc_now()
    formatted_month = handle_initial_zeros(now.month)
    formatted_day = handle_initial_zeros(now.day)
    formatted_hour = handle_initial_zeros(now.hour)
    "#{now.year}#{formatted_month}#{formatted_day}#{formatted_hour}"
  end

  defp update_rates(currency_rate_list) do
    Enum.each(currency_rate_list, &put/1)
    Database.store_sync(compose_exchange_key(), currency_rate_list, "exchange")
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

  @doc """
  Calculate the exchange equivalent amount between 2 currencies

  """
  def convert(amount, current_currency, new_currency) do
    current_rate = get!(current_currency)
    new_rate = get!(new_currency)
    exchange_rate = 1 / (current_rate / new_rate)
    {round(amount * exchange_rate), exchange_rate}
  end

  defmodule CurrencyError do
    @moduledoc false
    defexception message: "Invalid currency"
  end
end
