defmodule Account.Operation do
  @moduledoc """
  Pure functional module, used to define new operations that happen over an `Account` data structure

  By default, any operation is initialized with status `:done` and with the current date time

  If you want to change any key value of the operation struct you should pass it new value inside the data parameter
  eg: `Account.Operation.new(:type, %{status: :new_status} )`
  """

  @typedoc """
  Basic struct to define an `Account.Operation`

  The `Account.Operation.t()` data structure is composed by 5 values:
  - date_time: The date and time of the operation occurence
  - type: Atom that identifies the type of the operation
  - data: Customized data about the operation based on the operation type, can be used to inject metadata about the operation
  - status: Atom that indicates if the operation suceeded or not. [:done, :denied, :refunded]
  - id: Sequential identifier, that identifies the operation only inside an Account context
  """
  @type t() :: %Account.Operation{date_time: Date.t(), type: atom(), data: map()}
  defstruct date_time: nil, type: :type, data: %{}, status: :done, id: nil

  defp list_to_map(list) do
    for {k, v} <- list, into: %{} do
      {k, v}
    end
  end

  defp separate_key_arguments(entry_data) do
    key_args =
      entry_data
      |> Enum.filter(fn {key, _} -> Map.has_key?(%Account.Operation{}, key) end)
      |> list_to_map()
      |> Map.put_new(:date_time, DateTime.utc_now())

    data =
      entry_data
      |> Enum.filter(fn {key, _} -> Map.has_key?(%Account.Operation{}, key) === false end)
      |> list_to_map()

    {key_args, data}
  end

  @spec new(:withdraw, %{amount: number()} | map) :: Account.Operation.t()
  @doc """
  Create a new operation based on the parameters

  - Any extra data passed on the data parameter will be part of the final term, inside data key
  - You can pass key arguments on data to change operation default values such as `:date_time` and `:status`

  ## Examples
      iex> oop = Account.Operation.new(:withdraw, %{amount: 1000})
      iex> match?(%{date_time: _, type: :withdraw, data: %{amount: 1000}, status: :done}, oop)
      true

      #Any extra data passed on the data parameter will be part of the final term
      iex> oop = Account.Operation.new(:deposit, %{amount: 1000, meta_data: "some data"})
      iex> match?(%{data: %{amount: 1000, meta_data: "some data"}}, oop)
      true

      # Any key argument on data will change the operation default value for the provided key
      iex> oop = Account.Operation.new(:deposit, %{amount: 1000, status: "My custom status", date_time: ~U[2020-07-24 10:00:00Z]})
      iex> match?(%{status: "My custom status", date_time: ~U[2020-07-24 10:00:00Z]}, oop)
      true

  """
  def new(:withdraw, %{amount: amount} = entry_data)
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)
    Map.merge(%Account.Operation{type: :withdraw, data: data}, args)
  end

  @spec new(:deposit, %{amount: number()} | map) :: Account.Operation.t()
  def new(:deposit, %{amount: amount} = entry_data)
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)
    Map.merge(%Account.Operation{type: :deposit, data: data}, args)
  end

  @spec new(:transfer_out, %{amount: number(), recipient_account_id: number} | map) ::
          Account.Operation.t()
  def new(
        :transfer_out,
        %{amount: amount, recipient_account_id: _recipient_account_id} = entry_data
      )
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :transfer_out, data: data},
      args
    )
  end

  def new(
        :transfer_out,
        %{amount: amount} = entry_data
      )
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :transfer_out, data: data},
      args
    )
  end

  @spec new(:transfer_in, %{amount: number(), sender_account_id: number} | map) ::
          Account.Operation.t()
  def new(:transfer_in, %{amount: amount, sender_account_id: _sender_account_id} = entry_data)
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :transfer_in, data: data},
      args
    )
  end

  @spec new(:card_transaction, %{amount: number(), card_id: number} | map) ::
          Account.Operation.t()
  def new(:card_transaction, %{amount: amount, card_id: _card_number} = entry_data)
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :card_transaction, data: data},
      args
    )
  end

  @spec new(:refund, %{operation_to_refund_id: number} | map) :: Account.Operation.t()
  def new(
        :refund,
        %{amount: amount, operation_to_refund_id: _operation_to_refund_id} = entry_data
      )
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :refund, data: data},
      args
    )
  end

  @spec new(
          :exchange,
          %{
            current_amount: number,
            current_currency: atom,
            new_amount: number(),
            new_currency: atom(),
            exchange_rate: number
          }
          | map
        ) :: Account.Operation.t()
  def new(
        :exchange,
        %{
          current_amount: amount,
          current_currency: _,
          new_amount: _,
          new_currency: _,
          exchange_rate: _
        } = entry_data
      )
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :exchange, data: data},
      args
    )
  end

  @spec new(
          :exchange,
          %{
            current_amount: number,
            current_currency: atom,
            new_currency: atom(),
            status: :denied
          }
          | map
        ) :: Account.Operation.t()
  def new(
        :exchange,
        %{
          current_amount: amount,
          current_currency: _,
          new_currency: _,
          status: :denied
        } = entry_data
      )
      when is_integer(amount) and amount > 0 do
    {args, data} = separate_key_arguments(entry_data)

    Map.merge(
      %Account.Operation{type: :exchange, data: data},
      args
    )
  end
end
