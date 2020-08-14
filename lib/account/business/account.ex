defmodule Account do
  @moduledoc """
    Pure functional module that manages `Account` data structures

    - Operations are always registered on account's operations either if it is `:denied` or `:ok`
  """

  @typedoc """
  Basic struct that represents an `Account`

  The `Account.t()` data structure is composed by 5 values:
    - balances: map containing `%{currecy => balance}` eg: `%{BRL: 2500}`
    - limit: The minimal balance required to make operations, this feature only works for account's default currency other currencies are always 0
    - operations: A map containing all the operations of a specific Account. eg `%{1 => Account.Operation.t(), 2 => Account.Operation.t()}`
    - default_currency: Account's default currency used on limit feature
    - operations_auto_id: Used internally to generate operations ids
  """
  @type t() :: %__MODULE__{
          balances: map(),
          limit: integer(),
          operations: map(),
          operations_auto_id: integer(),
          default_currency: atom()
        }
  defstruct balances: %{BRL: 0},
            limit: -500,
            operations: %{},
            operations_auto_id: 1,
            default_currency: :BRL

  @spec new :: Account.t()
  @doc """
  Create a new `Account` data structure

  ## Examples
      iex> Account.new()
      %Account{balances: %{BRL: 0}, limit: -500, operations: %{}, operations_auto_id: 1}


  """
  def new() do
    %Account{}
  end
  @doc """
  Create a new `Account` data strucure with modified data

  ## Examples
      iex> entry_map = %{balances: %{BRL: 1000}, limit: -999}
      iex> Account.new(entry_map)
      %Account{balances: %{BRL: 1000}, limit: -999, operations: %{}, operations_auto_id: 1}
  """
  @spec new(map()) :: Account.t()
  def new(%{} = args) do
    new_account = %Account{}
    Map.merge(new_account, args)
  end

  @spec withdraw(Account.t(), %{amount: non_neg_integer(), currency: atom()}) ::
          {:ok, Account.t(), Account.Operation.t()}
          | {:denied, String.t(), Account.t(), Account.Operation.t()}
  @doc """
  Register an event of withdraw and update account's balance

  ## Examples

      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 300}},
      ...> %Account.Operation{type: :withdraw, data: %{amount: 700, currency: :BRL}}
      ...> } = Account.withdraw(init_account, %{amount: 700, currency: :BRL})


      iex> init_account = Account.new(%{balances: %{BRL: -500}})
      iex> {
      ...> :denied,
      ...> reason,
      ...> %Account{balances: %{BRL: -500}},
      ...> %Account.Operation{type: :withdraw, data: %{amount: 50, currency: :BRL}}
      ...> } = Account.withdraw(init_account, %{amount: 50, currency: :BRL})

  """
  def withdraw(%Account{} = account, %{amount: amount, currency: currency} = data) do
    case remove_balance(account, amount, currency) do
      {:ok, new_account} ->
        operation = Account.Operation.new(:withdraw, data)
        {new_account, operation_data} = register_operation(new_account, operation)
        {:ok, new_account, operation_data}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Account.Operation.new(:withdraw, operation_custom_data)
        {new_account, operation_data} = register_operation(account, operation)
        {:denied, reason, new_account, operation_data}
    end
  end

  @spec deposit(Account.t(), %{amount: pos_integer, currency: atom()}) ::
          {:ok, Account.t(), Account.Operation.t()}
  @doc """
  Register an event of deposit and update the balance

  ## Examples
      iex> init_account = Account.new()
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 700}},
      ...> %Account.Operation{type: :deposit, data: %{amount: 700, currency: :BRL}}
      ...> } = Account.deposit(init_account, %{amount: 700, currency: :BRL})

  """
  def deposit(%Account{} = account, %{amount: amount, currency: currency} = data) do
    {new_account, operation_data} =
      account
      |> add_balance(amount, currency)
      |> register_operation(Account.Operation.new(:deposit, data))

    {:ok, new_account, operation_data}
  end

  @spec transfer_out(
          Account.t(),
          %{amount: non_neg_integer(), currency: atom, recipient_account_id: number}
        ) ::
          {:ok, Account.t(), Account.Operation.t()}
          | {:denied, String.t(), Account.t(), Account.Operation.t()}
  @doc """
  Register an event of transfer_out for each data received on the list and update the balance

  - If suceeds, the split operation generates N :transfer_out operations on the account operation list
  - If it is denied, only one operation will be created on the operations lists
  - All the aditional data passed to data paramenter will be copied to each generated operation

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 300}},
      ...> %Account.Operation{type: :transfer_out, data: %{amount: 700, currency: :BRL}}
      ...> } = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1, currency: :BRL})

      iex> init_account = Account.new(%{balances: %{BRL: -500}})
      iex> {
      ...> :denied,
      ...> reason,
      ...> %Account{balances: %{BRL: -500}},
      ...> %Account.Operation{type: :transfer_out, data: %{amount: 700, currency: :BRL}}
      ...> } = Account.transfer_out(init_account, %{amount: 700, currency: :BRL, recipient_account_id: 1})

      iex> init_account = Account.new(%{balances: %{BRL: 3000}})
      iex> data = %{
      ...>  currency: :BRL,
      ...>  amount: 1000,
      ...>  recipients_data: [
      ...>    %{percentage: 0.7, recipient_account_id: 2},
      ...>    %{percentage: 0.2, recipient_account_id: 3},
      ...>    %{percentage: 0.1, recipient_account_id: 4}
      ...>  ]}
      iex>  {
      ...>  :ok,
      ...>  %Account{balances: %{BRL: 2000}},
      ...>  [
      ...>    %Account.Operation{data: %{amount: 100, currency: :BRL, recipient_account_id: 4}},
      ...>    %Account.Operation{data: %{amount: 200, currency: :BRL, recipient_account_id: 3}},
      ...>    %Account.Operation{data: %{amount: 700, currency: :BRL, recipient_account_id: 2}}
      ...> ]} = Account.transfer_out(init_account, data)

  """
  def transfer_out(
        %Account{} = account,
        %{amount: amount, currency: currency, recipient_account_id: _recipient_account_id} = data
      ) do
    case remove_balance(account, amount, currency) do
      {:ok, new_account} ->
        {new_account, operation_data} =
          register_operation(new_account, Account.Operation.new(:transfer_out, data))

        {:ok, new_account, operation_data}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Account.Operation.new(:transfer_out, operation_custom_data)
        {new_account, operation_data} = register_operation(account, operation)

        {:denied, reason, new_account, operation_data}
    end
  end

  @spec transfer_out(
          Account.t(),
          %{amount: non_neg_integer(), recipients_data: list()}
        ) ::
          {:ok, Account.t(), [Account.Operation.t()]}
          | {:denied, String.t(), Account.t(), Account.Operation.t()}

  def transfer_out(
        %Account{} = account,
        %{amount: amount, currency: currency, recipients_data: [_ | _] = _recipients_data} = data
      ) do
    case remove_balance(account, amount, currency) do
      {:ok, new_account} ->
        {new_account, operations_data_list} = process_recipient_data(new_account, data)
        {:ok, new_account, operations_data_list}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Account.Operation.new(:transfer_out, operation_custom_data)
        {new_account, operation_data} = register_operation(account, operation)

        {:denied, reason, new_account, operation_data}
    end
  end

  @spec transfer_in(Account.t(), %{amount: pos_integer, currency: atom, sender_account_id: any}) ::
          {:ok, Account.t(), Account.Operation.t()}
  @doc """
  Register an event of transfer in and update the balance

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 300}})
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 1000}},
      ...> %Account.Operation{type: :transfer_in, data: %{amount: 700, currency: :BRL, sender_account_id: 1}}
      ...> } = Account.transfer_in(init_account, %{amount: 700, currency: :BRL, sender_account_id: 1})
  """
  def transfer_in(
        %Account{} = account,
        %{amount: amount, currency: currency, sender_account_id: _sender_account_id} = data
      ) do
    {new_account, operation_data} =
      account
      |> add_balance(amount, currency)
      |> register_operation(Account.Operation.new(:transfer_in, data))

    {:ok, new_account, operation_data}
  end

  @spec card_transaction(Account.t(), %{amount: non_neg_integer(), currency: atom, card_id: any}) ::
          {:ok, Account.t(), Account.Operation.t()}
          | {:denied, String.t(), Account.t(), Account.Operation.t()}
  @doc """
  Register an event of card transaction and update the balance

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 300}},
      ...> %Account.Operation{type: :card_transaction, data: %{amount: 700, currency: :BRL}}
      ...> } = Account.card_transaction(init_account, %{amount: 700, currency: :BRL, card_id: 1})

      iex> init_account = Account.new(%{balances: %{BRL: -500}})
      iex> {
      ...> :denied,
      ...> reason,
      ...> %Account{balances: %{BRL: -500}},
      ...> %Account.Operation{type: :card_transaction, data: %{amount: 700, currency: :BRL}}
      ...> } = Account.card_transaction(init_account, %{amount: 700, currency: :BRL, card_id: 1})

  """
  def card_transaction(
        %Account{} = account,
        %{amount: amount, currency: currency, card_id: _card_number} = data
      ) do
    case(remove_balance(account, amount, currency)) do
      {:ok, new_account} ->
        operation = Account.Operation.new(:card_transaction, data)
        {new_account, operation_data} = register_operation(new_account, operation)
        {:ok, new_account, operation_data}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Account.Operation.new(:card_transaction, operation_custom_data)
        {new_account, operation_data} = register_operation(account, operation)
        {:denied, reason, new_account, operation_data}
    end
  end

  @spec refund(Account.t(), %{operation_to_refund_id: any}) ::
          {:ok, Account.t(), Account.Operation.t()}
          | {:error, String.t(), Account.t()}
  @doc """
  Register an event of refund, update de balance and update the refunded operation status

  - Only card operations are refundable, all other operations will return `{:error, reason, account_data}`

  ## Examples

      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {:ok, init_account, %{id: op_id}} = Account.card_transaction(init_account, %{amount: 700,currency: :BRL, card_id: 1})
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 1000}},
      ...> %Account.Operation{type: :refund, data: %{operation_to_refund_id: ^op_id}}
      ...> } = Account.refund(init_account, %{operation_to_refund_id: op_id})
  """
  def refund(
        %Account{} = account,
        %{operation_to_refund_id: operation_to_refund_id} = data
      ) do
    case operation_exists(account, operation_to_refund_id) do
      {:ok, operation_to_refund} ->
        case is_refundable(operation_to_refund) do
          {:ok, operation_to_refund} ->
            refund_amount = operation_to_refund.data.amount
            refund_currency = operation_to_refund.data.currency
            operation_custom_data = Map.put(data, :amount, refund_amount)
            operation = Account.Operation.new(:refund, operation_custom_data)

            {new_account, operation_data} =
              add_balance(account, refund_amount, refund_currency)
              |> update_operation_status(operation_to_refund_id, :refunded)
              |> register_operation(operation)

            {:ok, new_account, operation_data}

          {:error, reason} ->
            {:error, reason, account}
        end

      {:error, reason} ->
        {:error, reason, account}
    end
  end

  @doc """
  Register an event of exchange, update the balances based on exchange rates

  ## Examples

      iex> init_account = Account.new(%{balances: %{USD: 1000}})
      iex> {
      ...> :ok,
      ...> %Account{balances: %{BRL: 545, USD: 900}},
      ...> %Account.Operation{type: :exchange, status: :done}
      ...> } = Account.exchange_balances(init_account, %{current_amount: 100, current_currency: :USD, new_currency: :BRL})
  """
  def exchange_balances(
        %Account{} = account,
        %{current_amount: amount, current_currency: current_currency, new_currency: new_currency} =
          data
      ) do
    case remove_balance(account, amount, current_currency) do
      {:ok, new_account} ->
        {new_amount, exchange_rate} =
          Account.Exchange.convert(amount, current_currency, new_currency)

        operation_custom_data =
          data
          |> Map.put(:exchange_rate, exchange_rate)
          |> Map.put(:new_amount, new_amount)

        operation = Account.Operation.new(:exchange, operation_custom_data)

        {new_account, operation_data} =
          add_balance(new_account, new_amount, new_currency)
          |> register_operation(operation)

        {:ok, new_account, operation_data}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Account.Operation.new(:exchange, operation_custom_data)
        {new_account, operation_data} = register_operation(account, operation)
        {:denied, reason, new_account, operation_data}
    end
  end

  @doc """
  Get the current balance of the account for the given currency

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> Account.balance(init_account, :BRL)
      1000
  """
  @spec balance(Account.t(), atom()) :: number()
  def balance(%Account{} = account, currency) do
    Map.get(account.balances, currency, 0)
  end

  @doc """
  Get all the current balances of the account

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000, USD: 700, EUR: 300}})
      iex> Account.balances(init_account)
      %{BRL: 1000, USD: 700, EUR: 300}
  """
  @spec balances(Account.t()) :: map()
  def balances(%Account{} = account) do
    Map.get(account, :balances)
  end

  @doc """
  Get a ordered list of all the operations that happen on a given date, ordered by occurence date time

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {:ok, new_account, _} = Account.withdraw(init_account, %{amount: 700, currency: :BRL, date_time: ~U[2020-07-24 11:00:00Z]})
      iex> {:denied, _, new_account, _} = Account.withdraw(new_account, %{amount: 1300, currency: :BRL, date_time: ~U[2020-07-24 12:00:00Z]})
      iex> {:ok, new_account, _} = Account.deposit(new_account, %{amount: 700, currency: :BRL, date_time: ~U[2020-07-25 11:00:00Z]})
      iex> [
      ...>  %Account.Operation{type: :withdraw, data: %{amount: 1300, currency: :BRL}, status: :denied},
      ...>  %Account.Operation{type: :withdraw, data: %{amount: 700, currency: :BRL}, status: :done}
      ...> ] = Account.operations(new_account, ~D[2020-07-24])
  """
  @spec operations(Account.t(), Date.t()) :: [Account.Operation.t()]
  def operations(%Account{} = account, date) do
    account.operations
    |> Stream.filter(fn {_, operation} -> DateTime.to_date(operation.date_time) == date end)
    |> Enum.map(fn {_, operation} -> operation end)
    |> Enum.sort(&compare_operations(&1, &2))
  end

  @doc """
  Get a ordered list of all the operations that happen between 2 dates, ordered by occurence date time

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {:ok, new_account, _} = Account.withdraw(init_account, %{amount: 700, currency: :BRL, date_time: ~U[2020-07-24 11:00:00Z]})
      iex> {:denied, _, new_account, _} = Account.withdraw(new_account, %{amount: 1300, currency: :BRL, date_time: ~U[2020-07-24 12:00:00Z]})
      iex> {:ok, new_account, _} = Account.deposit(new_account, %{amount: 700, currency: :BRL, date_time: ~U[2020-07-25 11:00:00Z]})
      iex> {:ok, new_account, _} = Account.deposit(new_account, %{amount: 1800, currency: :BRL, date_time: ~U[2020-07-26 11:00:00Z]})
      iex> [
      ...>  %Account.Operation{type: :deposit, data: %{amount: 700, currency: :BRL}, status: :done},
      ...>  %Account.Operation{type: :withdraw, data: %{amount: 1300, currency: :BRL}, status: :denied},
      ...>  %Account.Operation{type: :withdraw, data: %{amount: 700, currency: :BRL}, status: :done}
      ...> ] = Account.operations(new_account, ~D[2020-07-24], ~D[2020-07-25])
  """
  @spec operations(Account.t(), Date.t(), Date.t()) :: [Account.Operation.t()]
  def operations(%Account{} = account, ini_date, fin_date) do
    account.operations
    |> Stream.filter(fn {_, operation} -> is_between(operation, ini_date, fin_date) end)
    |> Enum.map(fn {_, operation} -> operation end)
    |> Enum.sort(&compare_operations(&1, &2))
  end

  @doc """
  Get the account's operation under the given id

  ## Examples
      iex> init_account = Account.new(%{balances: %{BRL: 1000}})
      iex> {:ok, new_account, _} = Account.withdraw(init_account, %{amount: 700, currency: :BRL})
      iex> %Account.Operation{} = Account.operation(new_account, 1)

  """
  def operation(%Account{} = account, operation_id) do
    Map.get(account.operations, operation_id)
  end

  ## HELPERS ##
  @refundable_operations [:card_transaction]

  defp is_refundable(%Account.Operation{} = operation) do
    is_card_operation =
      Enum.find(@refundable_operations, nil, fn type -> type == operation.type end) !== nil

    is_done = operation.status === :done

    refundable = is_card_operation && is_done

    case refundable do
      true ->
        {:ok, operation}

      false ->
        {:error, "Unrefundable operation"}
    end
  end

  defp operation_exists(%Account{} = account, operation_id) do
    case Map.fetch(account.operations, operation_id) do
      :error ->
        {:error, "Account.Operation do not exists"}

      {:ok, operation} ->
        {:ok, operation}
    end
  end

  defp is_between(%Account.Operation{} = operation, ini, fin) do
    Helpers.is_date_between(DateTime.to_date(operation.date_time), ini, fin)
  end

  @spec register_operation(Account.t(), Account.Operation.t()) ::
          {Account.t(), Account.Operation.t()}
  defp register_operation(%Account{} = account, %Account.Operation{} = new_operation) do
    new_operation_entry = Map.put(new_operation, :id, account.operations_auto_id)

    new_operations = Map.put(account.operations, account.operations_auto_id, new_operation_entry)

    new_account = %Account{
      account
      | operations: new_operations,
        operations_auto_id: account.operations_auto_id + 1
    }

    {new_account, new_operation_entry}
  end

  defp remove_balance(%Account{} = account, amount, currency) do
    current_balance = Map.get(account.balances, currency, 0)
    new_balance = current_balance - amount

    is_default_currency? = currency === Map.get(account, :default_currency)

    limit = if is_default_currency?, do: account.limit, else: 0

    case new_balance >= limit do
      true ->
        new_balances = Map.put(account.balances, currency, new_balance)
        {:ok, Map.put(account, :balances, new_balances)}

      false ->
        {:denied, "No #{to_string(currency)} funds"}
    end
  end

  defp add_balance(%Account{} = account, amount, currency) do
    current_balance = Map.get(account.balances, currency, 0)
    new_balance = current_balance + amount
    new_balances = Map.put(account.balances, currency, new_balance)
    Map.put(account, :balances, new_balances)
  end

  defp compare_operations(op1, op2) do
    date_time_op1 = Map.get(op1, :date_time)
    date_time_op2 = Map.get(op2, :date_time)
    DateTime.diff(date_time_op1, date_time_op2, :millisecond) >= 0
  end

  defp update_operation_status(%Account{} = account, operation_id, new_status) do
    new_operation = Map.put(Map.get(account.operations, operation_id), :status, new_status)
    new_operations = Map.put(account.operations, operation_id, new_operation)
    Map.put(account, :operations, new_operations)
  end

  defp process_recipient_data(%Account{} = account, %{} = data) do
    custom_data = Map.delete(data, :recipients_data)
    total_amount = Map.get(data, :amount)

    {new_account, operation_data_list} =
      Map.get(data, :recipients_data)
      |> Stream.map(&update_recipient_data_amount(&1, total_amount))
      |> Stream.map(&Account.Operation.new(:transfer_out, Map.merge(custom_data, &1)))
      |> Enum.reduce({account, []}, fn operation, {account, operation_list} ->
        {new_account, operation_data} = register_operation(account, operation)
        {new_account, [operation_data | operation_list]}
      end)

    {new_account, operation_data_list}
  end

  defp update_recipient_data_amount(%{} = recipient_data, total_amount) do
    recipient_percentage = Map.get(recipient_data, :percentage, 1)
    recipient_amount = round(total_amount * recipient_percentage)

    Map.put_new(recipient_data, :amount, recipient_amount)
    |> Map.delete(:percentage)
  end
end
