defmodule Account do
  @moduledoc """
    Pure functional module that manages `Account`

    All events except `refunds` that are denied or done, will be saved on the operations data structure. Refunds are registered only if suceed.
  """
  @refundable_operations [:card_transaction]

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

  defp is_refundable(%Operation{} = operation) do
    is_card_operation =
      Enum.find(@refundable_operations, nil, fn type -> type == operation.type end) !== nil

    is_done = operation.status === :done

    is_card_operation && is_done
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
    new_balance = account.balance - amount

    if new_balance >= account.limit do
      new_account =
        %Account{account | balance: new_balance}
        |> register_operation(Operation.new(:withdraw, data))

      {:ok, new_account}
    else
      operation =
        Operation.new(
          :withdraw,
          Map.put(data, :message, "No funds"),
          %{status: :denied}
        )

      {:denied, "No funds", register_operation(account, operation)}
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
      %Account{account | balance: account.balance + amount}
      |> register_operation(Operation.new(:deposit, data))

    {:ok, new_account}
  end

  @spec transfer_out(Account.t(), %{amount: number, recipient_account_id: any}) ::
          {:ok, Account.t()} | {:denied, String.t(), Account.t()}
  @doc """
  Register an event of transfer out and update de balance

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
    new_balance = account.balance - amount

    if new_balance >= account.limit do
      new_account =
        %Account{account | balance: new_balance}
        |> register_operation(Operation.new(:transfer_out, data))

      {:ok, new_account}
    else
      operation =
        Operation.new(:transfer_out, Map.put(data, :message, "No funds"), %{status: :denied})

      {:denied, "No funds", register_operation(account, operation)}
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
      %Account{account | balance: account.balance + amount}
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
    new_balance = account.balance - amount

    if(new_balance >= account.limit) do
      new_account =
        %Account{account | balance: new_balance}
        |> register_operation(Operation.new(:card_transaction, data))

      {:ok, new_account}
    else
      operation =
        Operation.new(:card_transaction, Map.put(data, :message, "No funds"), %{status: :denied})

      {:denied, "No funds", register_operation(account, operation)}
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
    case Map.fetch(account.operations, operation_to_refund_id) do
      {:ok, operation_to_refund} ->
        if is_refundable(operation_to_refund) do
          new_account =
            %Account{account | balance: account.balance + operation_to_refund.data.amount}
            |> register_operation(
              Operation.new(
                :refund,
                Map.put(data, :amount, operation_to_refund.data.amount)
              )
            )

          {:ok, new_account}
        else
          {:error, "Unrefundable operation", account}
        end

      :error ->
        {:error, "Operation do not exists", account}
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
  Get all the operations that happen on a given date

  ## Examples
      iex> init_state = %{balance: 1000}
      iex> init_account = Account.new(init_state)
      iex> {:ok, new_account} = Account.withdraw(init_account, %{amount: 700})
      iex> oop_list = Account.operations(new_account, Date.utc_today())
      iex> match?([
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done}
      ...> ], oop_list)
      true

      iex> init_state = %{balance: 1000}
      iex> init_account = Account.new(init_state)
      iex> {:ok, new_account} = Account.withdraw(init_account, %{amount: 700})
      iex> {:denied, _, new_account} = Account.withdraw(new_account, %{amount: 1300})
      iex> oop_list = Account.operations(new_account, Date.utc_today())
      iex> match?([
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done},
      ...>  %Operation{type: :withdraw, data: %{amount: 1300}, status: :denied}
      ...> ], oop_list)
      true
  """
  @spec operations(Account.t(), Date.t()) :: [Operation.t()]
  def operations(%Account{} = account, date) do
    account.operations
    |> Stream.filter(fn {_, operation} -> DateTime.to_date(operation.date_time) == date end)
    |> Enum.map(fn {_, operation} -> operation end)
  end

  defp is_date_between(date, date_ini, date_fin) do
    ini_diff = Date.diff(date, date_ini)
    fin_diff = Date.diff(date, date_fin)
    ini_diff >= 0 && fin_diff <= 0
  end

  @doc """
  Get all the operations that happen between 2 dates

  TODO: Change the code to this function be testable

  ## Examples
  """
  @spec operations(Account.t(), Date.t(), Date.t()) :: [Operation.t()]
  def operations(%Account{} = account, ini_date, fin_date) do
    account.operations
    |> Stream.filter(fn {_, operation} ->
      is_date_between(DateTime.to_date(operation.date_time), ini_date, fin_date)
    end)
    |> Enum.map(fn {_, operation} -> operation end)
  end
end
