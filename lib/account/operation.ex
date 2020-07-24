defmodule Operation do
  @moduledoc """
  Pure functional module, used to define new operations that happen over an `Account`

  By default, any operation initialize with status `:done`

  If you want to chage the status of an operation you should pass it new value under the args parameter
  eg: `Operation.new(:type, data, %{status: :new_status})`
  """

  @typedoc """
  Basic struct to define an `Operation`

  The `Operation.t()` data structure is composed by 4 values:
  - Date Time: The date and time of the operation occurence
  - Type: Atom that identifies the type of the operation
  - Data: Customized data about the operation based on the operation type, can be used to pass metadata about the operation
  - Status: Atom that indicates if the operation suceeded or not
  """
  @type t() :: %Operation{date_time: Date.t(), type: atom(), data: map()}
  defstruct date_time: DateTime.utc_now(), type: :type, data: %{}, status: :done

  def new(type, data, args \\ %{})

  @spec new(:withdraw, %{amount: number()} | map, map) :: Operation.t()
  @doc """
  Create a new operation based on the parameters

  - Any data passed on args will be forwarded to the `Operation` creation and will be part of the final term
  - Any extra data passed on the data parameter will be part of the final term, inside data key

  ## Examples
      iex> oop = Operation.new(:withdraw, %{amount: 1000})
      iex> match?(%{date_time: _, type: :withdraw, data: %{amount: 1000}, status: :done}, oop)
      true

      #Any extra data passed on the data parameter will be part of the final term, inside data key
      iex> oop = Operation.new(:deposit, %{amount: 1000, meta_data: "some data"})
      iex> match?(%{data: %{amount: 1000, meta_data: "some data"}}, oop)
      true

      # Any data passed on args will be forwarded to the `Operation` creation and will be part of the final term
      iex> oop = Operation.new(:deposit, %{amount: 1000}, %{meta_data: 123})
      iex> match?(%{meta_data: 123}, oop)
      true

      # This feature can even be used to overwrite default values of `Operation`
      iex> oop = Operation.new(:card_transaction, %{amount: 1000, card_id: 1}, %{status: :my_new_status})
      iex> match?(%{status: :my_new_status}, oop)
      true

  """
  def new(:withdraw, %{amount: amount} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(%Operation{type: :withdraw, data: data}, args)
  end

  @spec new(:deposit, %{amount: number()} | map, map) :: Operation.t()
  def new(:deposit, %{amount: amount} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(%Operation{type: :deposit, data: data}, args)
  end

  @spec new(:transfer_out, %{amount: number(), recipient_account_id: number} | map, map) ::
          Operation.t()
  def new(
        :transfer_out,
        %{amount: amount, recipient_account_id: _recipient_account_id} = data,
        args
      )
      when is_integer(amount) and amount > 0 do
    Map.merge(
      %Operation{type: :transfer_out, data: data},
      args
    )
  end

  @spec new(:transfer_in, %{amount: number(), sender_account_id: number} | map, map) ::
          Operation.t()
  def new(:transfer_in, %{amount: amount, sender_account_id: _sender_account_id} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(
      %Operation{type: :transfer_in, data: data},
      args
    )
  end

  @spec new(:card_transaction, %{amount: number(), card_id: number} | map, map) :: Operation.t()
  def new(:card_transaction, %{amount: amount, card_id: _card_number} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(
      %Operation{type: :card_transaction, data: data},
      args
    )
  end

  @spec new(:refund, %{operation_to_refund_id: number}, map) :: Operation.t()
  def new(
        :refund,
        %{amount: amount, operation_to_refund_id: _operation_to_refund_id} = data,
        args
      )
      when is_integer(amount) and amount > 0 do
    Map.merge(
      %Operation{type: :refund, data: data},
      args
    )
  end
end
