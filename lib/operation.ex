defmodule Operation do
  @type t() :: %Operation{date_time: Date.t(), type: atom(), data: map()}
  defstruct date_time: DateTime.utc_now(), type: :type, data: %{}, status: :done

  def new(type, data, args \\ %{})

  def new(:withdraw, %{amount: amount} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(%Operation{type: :withdraw, data: data}, args)
  end

  def new(:deposit, %{amount: amount} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(%Operation{type: :deposit, data: data}, args)
  end

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

  def new(:transfer_in, %{amount: amount, sender_account_id: _sender_account_id} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(
      %Operation{type: :transfer_in, data: data},
      args
    )
  end

  def new(:card_transaction, %{amount: amount, card_id: _card_number} = data, args)
      when is_integer(amount) and amount > 0 do
    Map.merge(
      %Operation{type: :card_transaction, data: data},
      args
    )
  end

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
