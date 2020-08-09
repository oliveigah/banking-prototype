defmodule Account do
  @moduledoc """
    Pure functional module that manages `Account`

    All events except `refunds` that are denied or done, will be saved on the operations data structure. Refunds are registered only if suceed.
  """

  @typedoc """
  Basic struct to manage `Account`

  The `Account.t()` data structure is composed by 3 values:
  - Balance: The current account balance
  - Limit: The minimal value required to make out operations
  - Operations: A map containing all the operations of a specific Account. eg `%{1 => Operation.t(), 2 => Operation.t()}`
  - Operations Id: Used internally to generate operations ids
  """
  @type t() :: %__MODULE__{
          balance: integer(),
          limit: integer(),
          operations: map(),
          operations_auto_id: integer()
        }
  defstruct balance: 0, limit: -500, operations: %{}, operations_auto_id: 1

  @spec new :: Account.t()
  @doc """
  Create a new `Account`

  ## Examples
      iex> Account.new()
      %Account{balance: 0, limit: -500, operations: %{}, operations_auto_id: 1}

      iex> Account.new(nil)
      %Account{balance: 0, limit: -500, operations: %{}, operations_auto_id: 1}

      iex> entry_map = %{balance: 1000, limit: -999}
      iex> Account.new(entry_map)
      %Account{balance: 1000, limit: -999, operations: %{}, operations_auto_id: 1}
  """
  def new() do
    %Account{}
  end

  def new(nil) do
    %Account{}
  end

  @spec new(map()) :: Account.t()
  def new(%{} = args) do
    new_account = %Account{}
    Map.merge(new_account, args)
  end

  @spec withdraw(Account.t(), %{amount: number}) ::
          {:ok, Account.t()} | {:denied, String.t(), Account.t()}
  @doc """
  Register an event of withdraw and update de balance

  - The operation is registered on account's operations either if it is `:denied` or `:ok`

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.withdraw(init_account, %{amount: 700})
      iex> result.balance
      300

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.withdraw(init_account, %{amount: 700})
      iex> %{type: type, data: %{amount: amount}} = Map.get(result.operations, 1)
      iex> {type, amount}
      {:withdraw, 700}

      iex> init_state = %{balance: -950, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:denied, message, _} = Account.withdraw(init_account, %{amount: 50})
      iex> message
      "No funds"

  """
  def withdraw(%Account{} = account, %{amount: amount} = data) do
    case remove_balance(account, amount) do
      {:ok, new_account} ->
        operation = Operation.new(:withdraw, data)
        new_account = register_operation(new_account, operation)
        {:ok, new_account}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Operation.new(:withdraw, operation_custom_data)
        new_account = register_operation(account, operation)
        {:denied, reason, new_account}
    end
  end

  @spec deposit(Account.t(), %{amount: pos_integer}) :: {:ok, Account.t()}
  @doc """
  Register an event of deposit and update de balance

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.deposit(init_account, %{amount: 700})
      iex> result.balance
      1700

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.deposit(init_account, %{amount: 700})
      iex> %{type: type, data: %{amount: amount}} = Map.get(result.operations, 1)
      iex> {type, amount}
      {:deposit, 700}

      iex> init_state = %{balance: -1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.deposit(init_account, %{amount: 700})
      iex> result.balance
      -300

  """
  def deposit(%Account{} = account, %{amount: amount} = data) do
    new_account =
      account
      |> add_balance(amount)
      |> register_operation(Operation.new(:deposit, data))

    {:ok, new_account}
  end

  @spec transfer_out(Account.t(), %{amount: number, recipient_account_id: number}) ::
          {:ok, Account.t()} | {:denied, String.t(), Account.t()}
  @doc """
  Register an event of transfer out and update the balance

  - The operation is registered on account's operations either if it is `:denied` or `:ok`

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1})
      iex> result.balance
      300

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1})
      iex> %{type: type, data: %{amount: amount}} = Map.get(result.operations, 1)
      iex> {type, amount}
      {:transfer_out, 700}

      iex> init_state = %{balance: -950, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:denied, message, _} = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1})
      iex> message
      "No funds"

  """
  def transfer_out(
        %Account{} = account,
        %{amount: amount, recipient_account_id: _recipient_account_id} = data
      ) do
    case remove_balance(account, amount) do
      {:ok, new_account} ->
        new_account = register_operation(new_account, Operation.new(:transfer_out, data))
        {:ok, new_account}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Operation.new(:transfer_out, operation_custom_data)
        new_account = register_operation(account, operation)

        {:denied, reason, new_account}
    end
  end

  @doc """
  Register an event of transfer for each data received on the list and update the balance

  - If this suceed, the split operation generates N :transfer_out operations on the account operation list
  - If it is denied, only one operation will be created on the operations lists
  - All the aditional data passed to data paramenter will be copied to each generated opertion

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1})
      iex> result.balance
      300

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1})
      iex> %{type: type, data: %{amount: amount}} = Map.get(result.operations, 1)
      iex> {type, amount}
      {:transfer_out, 700}

      iex> init_state = %{balance: -950, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:denied, message, _} = Account.transfer_out(init_account, %{amount: 700, recipient_account_id: 1})
      iex> message
      "No funds"

  """
  def transfer_out(
        %Account{} = account,
        %{amount: amount, recipients_data: [_ | _] = _recipients_data} = data
      ) do
    case remove_balance(account, amount) do
      {:ok, new_account} ->
        new_account = process_recipient_data(new_account, data)

        {:ok, new_account}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Operation.new(:transfer_out, operation_custom_data)
        new_account = register_operation(account, operation)

        {:denied, reason, new_account}
    end
  end

  @spec transfer_in(Account.t(), %{amount: pos_integer, sender_account_id: any}) ::
          {:ok, Account.t()}
  @doc """
  Register an event of transfer in and update de balance

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_in(init_account, %{amount: 700, sender_account_id: 1})
      iex> result.balance
      1700

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_in(init_account, %{amount: 700, sender_account_id: 1})
      iex> %{type: type, data: %{amount: amount}} = Map.get(result.operations, 1)
      iex> {type, amount}
      {:transfer_in, 700}

      iex> init_state = %{balance: -1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.transfer_in(init_account, %{amount: 700, sender_account_id: 1})
      iex> result.balance
      -300

  """
  def transfer_in(
        %Account{} = account,
        %{amount: amount, sender_account_id: _sender_account_id} = data
      ) do
    new_account =
      account
      |> add_balance(amount)
      |> register_operation(Operation.new(:transfer_in, data))

    {:ok, new_account}
  end

  @spec card_transaction(Account.t(), %{amount: number, card_id: any}) ::
          {:ok, Account.t()} | {:denied, String.t(), Account.t()}
  @doc """
  Register an event of card transaction and update de balance

  - The operation is registered on account's operations either if it is `:denied` or `:ok`

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.card_transaction(init_account, %{amount: 700, card_id: 1})
      iex> result.balance
      300

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, result} = Account.card_transaction(init_account, %{amount: 700, card_id: 1})
      iex> %{type: type, data: %{amount: amount}} = Map.get(result.operations, 1)
      iex> {type, amount}
      {:card_transaction, 700}

      iex> init_state = %{balance: -950, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:denied, message, _} = Account.card_transaction(init_account, %{amount: 700, card_id: 1})
      iex> message
      "No funds"

  """
  def card_transaction(%Account{} = account, %{amount: amount, card_id: _card_number} = data) do
    case(remove_balance(account, amount)) do
      {:ok, new_account} ->
        operation = Operation.new(:card_transaction, data)
        new_account = register_operation(new_account, operation)
        {:ok, new_account}

      {:denied, reason} ->
        operation_custom_data = Map.merge(data, %{message: reason, status: :denied})
        operation = Operation.new(:card_transaction, operation_custom_data)
        new_account = register_operation(account, operation)
        {:denied, reason, new_account}
    end
  end

  @spec refund(Account.t(), %{operation_to_refund_id: any}) ::
          {:ok, Account.t()}
          | {:error, String.t(), Account.t()}
  @doc """
  Register an event of refund and update de balance

  - The operation is registered on account's operations onlf if it is `:ok`

  ## Examples
      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, new_account} = Account.card_transaction(init_account, %{amount: 700, card_id: 1})
      iex> {:ok, new_account} = Account.refund(new_account, %{operation_to_refund_id: 1})
      iex> new_account.balance
      1000

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:ok, new_account} = Account.withdraw(init_account, %{amount: 700})
      iex> {:error, message, _} = Account.refund(new_account, %{operation_to_refund_id: 1})
      iex> message
      "Unrefundable operation"

      iex> init_state = %{balance: 1000, limit: -999}
      iex> init_account = Account.new(init_state)
      iex> {:error, message, _} = Account.refund(init_account, %{operation_to_refund_id: 1})
      iex> message
      "Operation do not exists"

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
            operation_custom_data = Map.put(data, :amount, refund_amount)
            operation = Operation.new(:refund, operation_custom_data)

            new_account =
              add_balance(account, refund_amount)
              |> register_operation(operation)
              |> update_operation_status(operation_to_refund_id, :refunded)

            {:ok, new_account}

          {:error, reason} ->
            {:error, reason, account}
        end

      {:error, reason} ->
        {:error, reason, account}
    end
  end

  @doc """
  Get the current balance of the account

  ## Examples
      iex> init_state = %{balance: 1000}
      iex> init_account = Account.new(init_state)
      iex> Account.balance(init_account)
      1000
  """
  @spec balance(Account.t()) :: number()
  def balance(%Account{} = account) do
    account.balance
  end

  @doc """
  Get a ordered list of all the operations that happen on a given date, ordered by occurence date time

  ## Examples
      iex> init_state = %{balance: 1000}
      iex> init_account = Account.new(init_state)
      iex> {:ok, new_account} = Account.withdraw(init_account, %{amount: 700, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> oop_list = Account.operations(new_account, ~D[2020-07-24])
      iex> [
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done}
      ...> ] = oop_list

      iex> init_state = %{balance: 1000}
      iex> init_account = Account.new(init_state)
      iex> {:ok, new_account} = Account.withdraw(init_account, %{amount: 700, date_time: ~U[2020-07-24 11:00:00Z]})
      iex> {:denied, _, new_account} = Account.withdraw(new_account, %{amount: 1300, date_time: ~U[2020-07-24 12:00:00Z]})
      iex> {:ok, new_account} = Account.deposit(new_account, %{amount: 700, date_time: ~U[2020-07-25 11:00:00Z]})
      iex> oop_list = Account.operations(new_account, ~D[2020-07-24])
      iex> [
      ...>  %Operation{type: :withdraw, data: %{amount: 1300}, status: :denied},
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done}
      ...> ] = oop_list
  """
  @spec operations(Account.t(), Date.t()) :: [Operation.t()]
  def operations(%Account{} = account, date) do
    account.operations
    |> Stream.filter(fn {_, operation} -> DateTime.to_date(operation.date_time) == date end)
    |> Enum.map(fn {_, operation} -> operation end)
    |> Enum.sort(&compare_operations(&1, &2))
  end

  @doc """
  Get a ordered list of all the operations that happen between 2 dates, ordered by occurence date time

  ## Examples

    iex> init_state = %{balance: 1000}
    iex> init_account = Account.new(init_state)
    iex> {:ok, new_account} = Account.withdraw(init_account, %{amount: 700, date_time: ~U[2020-07-24 11:00:00Z]})
    iex> {:denied, _, new_account} = Account.withdraw(new_account, %{amount: 1300, date_time: ~U[2020-07-24 12:00:00Z]})
    iex> {:ok, new_account} = Account.deposit(new_account, %{amount: 700, date_time: ~U[2020-07-25 11:00:00Z]})
    iex> {:ok, new_account} = Account.deposit(new_account, %{amount: 1800, date_time: ~U[2020-07-26 11:00:00Z]})
    iex> oop_list = Account.operations(new_account, ~D[2020-07-24], ~D[2020-07-25] )
    iex> [
    ...>  %Operation{type: :deposit, data: %{amount: 700}, status: :done},
    ...>  %Operation{type: :withdraw, data: %{amount: 1300}, status: :denied},
    ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done}
    ...> ] = oop_list
  """
  @spec operations(Account.t(), Date.t(), Date.t()) :: [Operation.t()]
  def operations(%Account{} = account, ini_date, fin_date) do
    account.operations
    |> Stream.filter(fn {_, operation} -> is_between(operation, ini_date, fin_date) end)
    |> Enum.map(fn {_, operation} -> operation end)
    |> Enum.sort(&compare_operations(&1, &2))
  end

  def operation(%Account{} = account, operation_id) do
    Map.get(account.operations, operation_id)
  end

  ## HELPERS ##
  @refundable_operations [:card_transaction]

  defp is_refundable(%Operation{} = operation) do
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
        {:error, "Operation do not exists"}

      {:ok, operation} ->
        {:ok, operation}
    end
  end

  defp is_between(%Operation{} = operation, ini, fin) do
    Helpers.is_date_between(DateTime.to_date(operation.date_time), ini, fin)
  end

  defp register_operation(%Account{} = account, %Operation{} = new_operation) do
    new_operation_entry = Map.put(new_operation, :id, account.operations_auto_id)

    new_operations = Map.put(account.operations, account.operations_auto_id, new_operation_entry)

    %Account{
      account
      | operations: new_operations,
        operations_auto_id: account.operations_auto_id + 1
    }
  end

  defp remove_balance(%Account{} = account, amount) do
    new_balance = account.balance - amount

    case new_balance >= account.limit do
      true -> {:ok, Map.put(account, :balance, new_balance)}
      false -> {:denied, "No funds"}
    end
  end

  defp add_balance(%Account{} = account, amount) do
    new_balance = account.balance + amount
    Map.put(account, :balance, new_balance)
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

    Map.get(data, :recipients_data)
    |> Stream.map(&update_recipient_data_amount(&1, total_amount))
    |> Stream.map(&Operation.new(:transfer_out, Map.merge(custom_data, &1)))
    |> Enum.reduce(account, fn operation, account -> register_operation(account, operation) end)
  end

  defp update_recipient_data_amount(%{} = recipient_data, total_amount) do
    recipient_percentage = Map.get(recipient_data, :percentage, 1)
    recipient_amount = round(total_amount * recipient_percentage)

    Map.put_new(recipient_data, :amount, recipient_amount)
    |> Map.delete(:percentage)
  end
end
