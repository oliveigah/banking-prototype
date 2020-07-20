defmodule Operation do
  @type t() :: %Operation{date_time: Date.t(), type: atom(), data: map()}
  defstruct date_time: NaiveDateTime.utc_now(), type: :type, data: %{}

  def new(:withdraw, %{amount: amount} = data)
      when is_integer(amount) and amount > 0 do
    %Operation{type: :withdraw, data: data}
  end

  def new(:deposit, %{amount: amount} = data)
      when is_integer(amount) and amount > 0 do
    %Operation{type: :deposit, data: data}
  end

  def new(:transfer_out, %{amount: amount, recipient_account_id: _recipient_account_id} = data)
      when is_integer(amount) and amount > 0 do
    %Operation{
      type: :transfer_out,
      data: data
    }
  end

  def new(:transfer_in, %{amount: amount, sender_account_id: _sender_account_id} = data)
      when is_integer(amount) and amount > 0 do
    %Operation{
      type: :transfer_in,
      data: data
    }
  end

  def new(:card_transaction, %{amount: amount, card_id: _card_number} = data)
      when is_integer(amount) and amount > 0 do
    %Operation{
      type: :card_transaction,
      data: data
    }
  end

  def new(:refund, %{amount: amount, operation_to_refund_id: _operation_to_refund_id} = data)
      when is_integer(amount) and amount > 0 do
    %Operation{
      type: :refund,
      data: data
    }
  end
end
