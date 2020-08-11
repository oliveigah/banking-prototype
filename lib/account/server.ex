defmodule Account.Server do
  @dialyzer {:Woverspecs, transfer_out: 2}
  @moduledoc """
    Generic server process that keeps track of an `Account` module as it's state

    - Results of types like `:ok` and `:denied` will be registered on the `Account` operations list
    - Results of types like `:error` will NOT BE registered on the `Account` operations list

  """
  use GenServer, restart: :temporary

  @database_folder "accounts"
  @idle_timeout :timer.seconds(240)

  @impl GenServer
  def init(%{id: account_id} = args) do
    send(self(), {:real_init, account_id, args})
    {:ok, nil}
  end

  @spec start_link(%{id: number}) :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the `Account.Server` server

  - Should not be called directly, instead use `Account.Cache.server_process/2`
  - The initial state of non persisted non args `Account.Server` processes is the result of `Account.new/0`
  """
  def start_link(%{id: account_id} = args) do
    GenServer.start_link(Account.Server, args, name: via_tuple(account_id))
  end

  @spec withdraw(pid, %{amount: non_neg_integer(), currency: atom}) ::
          {:ok, number, Operation.t()} | {:denied, String.t(), number, Operation.t()}
  @doc """
  Withdraw from the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> {
      ...>  :ok,
      ...>  1000,
      ...>  %Operation{type: :withdraw, status: :done, data: %{amount: 2000, currency: :BRL}}
      ...> } = Account.Server.withdraw(server_pid, %{amount: 2000, currency: :BRL})

      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 500}})
      iex> {
      ...>  :denied,
      ...>  reason,
      ...>  500,
      ...>  %Operation{type: :withdraw, status: :denied, data: %{amount: 2000, currency: :BRL}}
      ...> } = Account.Server.withdraw(server_pid, %{amount: 2000, currency: :BRL})
  """
  def withdraw(account_server, %{amount: _} = data) do
    GenServer.call(account_server, {:withdraw, data})
  end

  def balances(account_server) do
    GenServer.call(account_server, :balances)
  end

  @spec deposit(pid, %{amount: non_neg_integer(), currency: atom}) :: {:ok, number, Operation.t()}
  @doc """
  Deposit into the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> {
      ...>  :ok,
      ...>  5000,
      ...>  %Operation{type: :deposit, status: :done, data: %{amount: 2000, currency: :BRL}}
      ...> } = Account.Server.deposit(server_pid, %{amount: 2000, currency: :BRL})
  """
  def deposit(account_server, %{amount: _, currency: _} = data) do
    GenServer.call(account_server, {:deposit, data})
  end

  @spec transfer_in(pid, %{amount: non_neg_integer, currency: atom, sender_account_id: number}) ::
          {:ok, number, Operation.t()}
  @doc """
  Deposit into the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> {
      ...>  :ok,
      ...>  5000,
      ...>  %Operation{type: :transfer_in, status: :done, data: %{amount: 2000, currency: :BRL}}
      ...> } = Account.Server.transfer_in(server_pid, %{amount: 2000, currency: :BRL, sender_account_id: 2})
  """
  def transfer_in(account_server, %{amount: _, currency: _, sender_account_id: _} = data) do
    GenServer.call(account_server, {:transfer_in, data})
  end

  @spec transfer_out(pid, %{amount: non_neg_integer, currency: atom, recipient_account_id: number}) ::
          {:ok, number, number, Operation.t(), Operation.t()}
          | {:denied, String.t(), number, Operation.t()}
  @doc """
  Transfer resources to another account

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> {
      ...>  :ok,
      ...>  1000,
      ...>  %Operation{type: :transfer_out, status: :done, data: %{amount: 2000,currency: :BRL, recipient_account_id: 2}},
      ...>  %Operation{type: :transfer_in, status: :done, data: %{amount: 2000,currency: :BRL, sender_account_id: 1}}
      ...> } = Account.Server.transfer_out(server_pid, %{amount: 2000, currency: :BRL, recipient_account_id: 2})

      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 500}})
      iex> {
      ...>  :denied,
      ...>  reason,
      ...>  500,
      ...>  %Operation{type: :transfer_out, status: :denied, data: %{amount: 2000, currency: :BRL}}
      ...> } = Account.Server.transfer_out(server_pid, %{amount: 2000, currency: :BRL, recipient_account_id: 2})
  """
  def transfer_out(
        account_server,
        %{amount: _, currency: _, recipient_account_id: _recipient} = data
      ) do
    GenServer.call(account_server, {:transfer_out, data})
  end

  @spec transfer_out(pid, %{amount: number, currency: atom, recipients_data: list()} | map) ::
          {:ok, number, number, [Operation.t()], [Operation.t()]}
          | {:denied, String.t(), number, Operation.t()}
  def transfer_out(
        account_server,
        %{amount: _, currency: _, recipients_data: [_ | _]} = data
      ) do
    GenServer.call(account_server, {:transfer_out, data})
  end

  @spec card_transaction(pid, %{amount: number, currency: atom, card_id: number}) ::
          {:ok, number, Operation.t()} | {:denied, String.t(), number, Operation.t()}
  @doc """
  Debit card operation that uses resources from the account balances

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> {
      ...>  :ok,
      ...>  1000,
      ...>  %Operation{type: :card_transaction, status: :done, data: %{amount: 2000, currency: :BRL, card_id: 1}},
      ...> } = Account.Server.card_transaction(server_pid, %{amount: 2000, currency: :BRL, card_id: 1})

      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 500}})
      iex> {
      ...>  :denied,
      ...>  reason,
      ...>  500,
      ...>  %Operation{type: :card_transaction, status: :denied, data: %{amount: 2000, currency: :BRL}}
      ...> } = Account.Server.card_transaction(server_pid, %{amount: 2000, currency: :BRL, card_id: 1})
  """
  def card_transaction(account_server, %{amount: _, currency: _, card_id: _} = data) do
    GenServer.call(account_server, {:card_transaction, data})
  end

  @spec refund(pid, %{operation_to_refund_id: any}) ::
          {:ok, map, Operation.t()}
          | {:denied, String.t(), number(), Operation.t()}
          | {:error, String.t(), Operation.t()}
  @doc """
  Register a refund operation, restore the amount to balance and update operation status to `:refunded`

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, currency: :BRL, card_id: 1})
      iex> {
      ...>  :ok,
      ...>  %{BRL: 3000},
      ...>  %Operation{type: :refund, status: :done, data: %{operation_to_refund_id: 1}},
      ...> } = Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
  """
  def refund(account_server, %{operation_to_refund_id: _} = data) do
    GenServer.call(account_server, {:refund, data})
  end

  @spec balance(pid, atom) :: number
  @doc """
  Get the current balance of the Account

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 3000}})
      iex> Account.Server.balance(server_pid, :BRL)
      3000
  """
  def balance(account_server, currency) do
    GenServer.call(account_server, {:balance, currency})
  end

  @spec operations(pid, Date.t()) :: [Operation.t()]
  @doc """
  Get the list of operations that occur in a specific date

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 2000}})
      iex> Account.Server.withdraw(server_pid, %{amount: 300, currency: :BRL, date_time: ~U[2020-07-23 10:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 700, currency: :BRL, date_time: ~U[2020-07-24 11:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 1900, currency: :BRL, date_time: ~U[2020-07-24 12:00:00Z]})
      iex> [
      ...>  %Operation{type: :withdraw, data: %{amount: 1900, currency: :BRL}, status: :denied},
      ...>  %Operation{type: :withdraw, data: %{amount: 700, currency: :BRL}, status: :done}
      ...> ] = Account.Server.operations(server_pid, ~D[2020-07-24])
  """
  def operations(account_server, date) do
    GenServer.call(account_server, {:operations, date})
  end

  @spec operations(pid, Date.t(), Date.t()) :: [Operation.t()]
  @doc """
  Get the list of operations that occur betweem 2 dates, ordered by occurence date time

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balances: %{BRL: 2000}})
      iex> Account.Server.withdraw(server_pid, %{amount: 300, currency: :BRL, date_time: ~U[2020-07-23 10:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 700, currency: :BRL, date_time: ~U[2020-07-24 11:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 1900, currency: :BRL, date_time: ~U[2020-07-25 12:00:00Z]})
      iex> [
      ...>  %Operation{type: :withdraw, data: %{amount: 700, currency: :BRL}, status: :done},
      ...>  %Operation{type: :withdraw, data: %{amount: 300, currency: :BRL}, status: :done}
      ...> ] = Account.Server.operations(server_pid, ~D[2020-07-23], ~D[2020-07-24])
  """
  def operations(account_server, date_ini, date_fin) do
    GenServer.call(account_server, {:operations, date_ini, date_fin})
  end

  @spec account_id(pid) :: number()
  @doc """
  Get the account id of a specific account

  ## Examples
      iex> server_pid = Account.Cache.server_process(123)
      iex> Account.Server.account_id(server_pid)
      123
  """
  def account_id(account_server) do
    GenServer.call(account_server, :account_id)
  end

  @spec operation(pid, number()) :: Operation.t() | nil
  @doc """
  Get operation data under the given id

  ## Examples
      iex> server_pid = Account.Cache.server_process(123)
      iex> Account.Server.deposit(server_pid, %{amount: 1000, currency: :BRL})
      iex> %Operation{
      ...>   type: :deposit,
      ...>   data: %{amount: 1000, currency: :BRL},
      ...>   status: :done
      ...> } = Account.Server.operation(server_pid, 1)

  """
  def operation(account_server, operation_id) do
    GenServer.call(account_server, {:operation, operation_id})
  end

  @impl GenServer
  def handle_call(:account_id, _from, %Account{} = current_state) do
    {:reply, Map.get(current_state, :id), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:balance, currency}, _from, %Account{} = current_state) do
    {:reply, Account.balance(current_state, currency), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:operations, date}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:operations, date_ini, date_fin}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date_ini, date_fin), current_state, @idle_timeout}
  end

  def handle_call({:operation, operation_id}, _from, %Account{} = current_state) do
    {:reply, Account.operation(current_state, operation_id), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call(
        {:withdraw, %{amount: _, currency: currency} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.withdraw(current_state, data) do
      {:ok, new_state, operation_data} ->
        persist_data(new_state)

        {:reply, {:ok, Account.balance(new_state, currency), operation_data}, new_state,
         @idle_timeout}

      {:denied, reason, new_state, operation_data} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, Account.balance(new_state, currency), operation_data},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call(
        {:deposit, %{amount: _, currency: currency} = data},
        _from,
        %Account{} = current_state
      ) do
    {:ok, new_state, operation_data} = Account.deposit(current_state, data)
    persist_data(new_state)

    {:reply, {:ok, Account.balance(new_state, currency), operation_data}, new_state,
     @idle_timeout}
  end

  @impl GenServer
  def handle_call(
        {:transfer_in, %{amount: _, currency: currency, sender_account_id: _} = data},
        _from,
        %Account{} = current_state
      ) do
    {:ok, new_state, operation_data} = Account.transfer_in(current_state, data)
    persist_data(new_state)

    {:reply, {:ok, Account.balance(new_state, currency), operation_data}, new_state,
     @idle_timeout}
  end

  @impl GenServer
  def handle_call(
        {:transfer_out, %{amount: _, currency: currency, recipient_account_id: recipient} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.transfer_out(current_state, data) do
      {:ok, new_state, operation_data} ->
        sender_id = Map.get(new_state, :id)

        recipient_operation_data = transfer_to_account(data, sender_id, recipient)

        persist_data(new_state)

        {
          :reply,
          {:ok, Account.balance(new_state, currency), operation_data, recipient_operation_data},
          new_state,
          @idle_timeout
        }

      {:denied, reason, new_state, operation_data} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, Account.balance(new_state, currency), operation_data},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call(
        {:transfer_out,
         %{amount: _, currency: currency, recipients_data: [_ | _] = recipients_data} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.transfer_out(current_state, data) do
      {:ok, new_state, operation_data_list} ->
        sender_id = Map.get(new_state, :id)

        recipients_operations_list = transfer_to_account_list(data, sender_id, recipients_data)

        persist_data(new_state)

        {
          :reply,
          {:ok, Account.balance(new_state, currency), operation_data_list,
           recipients_operations_list},
          new_state,
          @idle_timeout
        }

      {:denied, reason, new_state, operation_data} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, Account.balance(new_state, currency), operation_data},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call(
        {:card_transaction, %{amount: _, currency: currency, card_id: _} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.card_transaction(current_state, data) do
      {:ok, new_state, operation_data} ->
        persist_data(new_state)

        {:reply, {:ok, Account.balance(new_state, currency), operation_data}, new_state,
         @idle_timeout}

      {:denied, reason, new_state, operation_data} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, Account.balance(new_state, currency), operation_data},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call(
        {:refund, %{operation_to_refund_id: _operation_to_refund_id} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.refund(current_state, data) do
      {:ok, new_state, operation_data} ->
        persist_data(new_state)

        {:reply, {:ok, Account.balances(new_state), operation_data}, new_state, @idle_timeout}

      {:error, reason, new_state} ->
        {:reply, {:error, reason, Account.balances(new_state)}, new_state, @idle_timeout}
    end
  end

  @impl GenServer
  def handle_call(:balances, _from, %Account{} = current_state) do
    {:reply, Account.balances(current_state), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_info({:real_init, account_id, args}, _state) do
    case Database.get(account_id, @database_folder) do
      nil ->
        account = Account.new(args)
        persist_data(account)
        {:noreply, account, @idle_timeout}

      data ->
        {:noreply, data, @idle_timeout}
    end
  end

  @impl GenServer
  def handle_info(:timeout, %Account{} = state) do
    {:stop, :normal, state}
  end

  ### HELPERS
  defp persist_data(%Account{} = account_data) do
    Database.store_sync(Map.get(account_data, :id), account_data, @database_folder)
  end

  defp transfer_to_account_list(
         %{amount: total_} = data,
         sender_id,
         [_ | _] = recipients_data
       ) do
    parsed_recipients_data =
      recipients_data
      |> Stream.map(&Map.merge(data, &1))
      |> Stream.map(&calculate_operation_(&1, total_))
      |> Enum.map(&remove_fields(&1, [:percentage, :recipients_data]))

    parsed_recipients_data
    |> Enum.map(
      &Task.async(fn -> transfer_to_account(&1, sender_id, Map.get(&1, :recipient_account_id)) end)
    )
    |> Enum.map(&Task.await/1)
  end

  defp calculate_operation_(%{} = data, total_) do
    percentage = Map.get(data, :percentage)
    Map.put(data, :amount, round(total_ * percentage))
  end

  defp transfer_to_account(%{amount: amount} = data, sender_id, recipient_id) do
    transfer_data =
      Map.merge(data, %{
        amount: amount,
        sender_account_id: sender_id
      })

    {:ok, _, recipient_operation_data} =
      Account.Cache.server_process(recipient_id)
      |> Account.Server.transfer_in(transfer_data)

    recipient_operation_data
  end

  defp remove_fields(%{} = data, [_ | _] = keys_to_delete) do
    Enum.reduce(keys_to_delete, data, fn key, map ->
      Map.delete(map, key)
    end)
  end

  defp via_tuple(account_id) do
    Account.ProcessRegistry.via_tuple({__MODULE__, account_id})
  end
end
