defmodule Teste do
  # elixir -S mix run -e Teste.run
  def run do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{amount: 7000, date_time: ~U[2020-07-23 10:00:00Z]})

    data = %{
      amount: 1000,
      meta_data: "general meta_data",
      date_time: ~U[2020-07-24 10:00:00Z],
      recipients_data: [
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.1, recipient_account_id: 4}
      ]
    }

    {time, _} =
      :timer.tc(fn ->
        Account.Server.transfer_out(bob_account_pid, data)
      end)

    IO.puts(div(time, 1000))
  end
end
