defmodule Account.Server do
  use GenServer

  @impl GenServer
  @spec init(any) :: {:ok, Account.t()}
  def init(_) do
    {:ok, Account.new()}
  end

  def start() do
    GenServer.start(Account.Server, nil)
  end

  def withdraw(account_server, %{amount: _amount} = data) do
    GenServer.call(account_server, {:withdraw, data})
  end

  def deposit(account_server, %{amount: _amount} = data) do
    GenServer.call(account_server, {:deposit, data})
  end

  def transfer_in(account_server, %{amount: _amount, sender_account_id: _sender} = data) do
    GenServer.call(account_server, {:transfer_in, data})
  end

  def transfer_out(account_server, %{amount: _amount, recipient_account_id: _recipient} = data) do
    GenServer.call(account_server, {:transfer_out, data})
  end

  def card_transaction(account_server, %{amount: _amount, card_id: _card} = data) do
    GenServer.call(account_server, {:card_transaction, data})
  end

  def refund(account_server, %{operation_to_refund_id: _operation} = data) do
    GenServer.call(account_server, {:refund, data})
  end

  def balance(account_server) do
    GenServer.call(account_server, :balance)
  end

  def operations_date(account_server, date) do
    GenServer.call(account_server, {:operations, date})
  end

  def operations_between_dates(account_server, date_ini, date_fin) do
    GenServer.call(account_server, {:operations, date_ini, date_fin})
  end

  @impl GenServer
  def handle_call(:balance, _from, %Account{} = current_state) do
    {:reply, Account.balance(current_state), current_state}
  end

  @impl GenServer
  def handle_call({:operations, date}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date), current_state}
  end

  @impl GenServer
  def handle_call({:operations, date_ini, date_fin}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date_ini, date_fin), current_state}
  end

  @impl GenServer
  def handle_call({:withdraw, %{amount: _amount} = data}, _from, %Account{} = current_state) do
    case Account.withdraw(current_state, data) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.balance}, new_state}

      {:denied, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:deposit, %{amount: _amount} = data}, _from, %Account{} = current_state) do
    {:ok, new_state} = Account.deposit(current_state, data)
    {:reply, {:ok, new_state.balance}, new_state}
  end

  @impl GenServer
  def handle_call(
        {:transfer_in, %{amount: _amount, sender_account_id: _sender} = data},
        _from,
        %Account{} = current_state
      ) do
    {:ok, new_state} = Account.transfer_in(current_state, data)
    {:reply, {:ok, new_state.balance}, new_state}
  end

  @impl GenServer
  def handle_call(
        {:transfer_out, %{amount: _amount, recipient_account_id: _recipient} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.transfer_out(current_state, data) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.balance}, new_state}

      {:denied, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
    end
  end

  @impl GenServer
  def handle_call(
        {:card_transaction, %{amount: _amount, card_id: _card} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.card_transaction(current_state, data) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.balance}, new_state}

      {:denied, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
    end
  end

  @impl GenServer
  def handle_call(
        {:refund, %{operation_to_refund_id: _operation} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.refund(current_state, data) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.balance}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
    end
  end
end
