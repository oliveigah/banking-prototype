# System Overview

The goal of the system is to be a prototype of how to build a complete banking account management system that allows users to keep track of operations that happen over their account's and make operations like transfers, deposits and refunds.

The system is made of 2 basic entities:
- `Account`: The basic structure of the system, responsible for hold operations data, balances and the business rules to make everything work properley
- `Account.Operation`: Basic structure that holds data of an operation such as type, status and custom data like amount and currency, is responsible for the operation's creation rules

![System Entities](./assets/exdocs_assets/diagrams/system_entities.png)

An account has N operations, each one of them has data that identifies what happened in that operation.

## Running the system
Requirements: Elixir version >= 1.10

Steps:
1 - Clone the repository: https://github.com/oliveigah/banking_prototype
2 - On terminal, inside repository folder use the following commands:
    - `mix deps.get` to install the dependencies
    - `mix test` to verify if it is all good
    - `iex -S mix` running the system
3 - You are good to go! :D

## Interacting
You can interact with the system in 2 different ways. 

The first one is directly via the interactive shell. To do this you can check out the documentarion over the modules section. There you will find a set of examples of how to interact with the system via interactive shell and manage accounts on it. 

The main functions to start are `Account.Cache.server_process/2` which will be used to get the `pid` of the server you will interact with, and all functions of the `Account.Server` which will be used to execute all the operations over the account!

The second way to interact with the system is by using HTTP requests, this is described on the HTTP page.

## Account Features

- Accounts can hold balances on multiple currencies
- Exchange currencies based on the exchange rate
- Make operations over his own account:
    - Deposit
    - Withdraw
    - Transfer to another account
    - Card transaction
    - Refunds
    - Exchange two different currencies balances
- All these operations works with all currencies avaiable on the system, but the exchange has to happen before the operation it self, otherwise it will return "no {currency} funds"
- A "syntax sugar" that enable multiple transfer being done with a single request
- Allows users to give metadata information about the operations
- Filter operations over an account by occurrence date time and id
- Special limit that allow account balances go below 0 until a predefined threshold, this feature only works for account's default currency

## System Design

The system has a very simple design that relies on key abstractions of the elixir language such as `GenServer`, `Supervisor` and `Registry`. 

Some of the technical solutions are admittedly not optimal, but these non optimal parts are usually on side systems like the database and authentication and not part of the core implementation.

Below you can see a high level diagram that explain the system component's relations in a non rigorous manner:

![System Overview](./assets/exdocs_assets/diagrams/system_overview.png)



## Data Representation
The account data is composed by a simple struct as explained in `Account` module documentation.

```elixir
  @type t() :: %__MODULE__{
          balances: map(),
          limit: integer(),
          operations: map(),
          operations_auto_id: integer(),
          default_currency: atom()
        }
```

All mapipulations over an account data structure, has to be done as a function call to a predifened function inside `Account` module. This rule helps to keep the business rules well defined inside a single module that can be read and verified easily, either by new programmers arriving at the project and business experts.

This rule enables business experts verify the correctness of the system easier and automated tests being done faster and with less dependencies, for instance look at the code below:

```elixir
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
```

All the code that validates if a withdraw operation can be done or not (business rules) is inside this well defined function with no external dependencies or exoteric programming concepts such as databases, data serialization, pids, etc. All the rules are writen in a very high level code, that uses the account data abstraction that a busniess expert can understand and reason about.

Beyond being "business/test friendly" this patten enable all business rules being reusable by any communication platform. For instance, the HTTP platform implemented on this project is just a mean to an end that is interact with the system. Nothing can be done with a HTTP request and not inside the system interactive shell.

This design is based on "Clean Architecture" and it's know for decoupling business rules (`Account`), use cases (`Account.Server`) and external systems (`Database`, HTTP).


## Account Server

With it we can understand the system as an API to create operations over an account, the module `Account` is a pure functional module used by server process `Account.Server` to manipulate its own internal state that is an account.

Note that the `Account.Server` is just a representation of an specific account while the `Account` is a module that is used to handle all specific servers accounts, applying the business rules with the given data.

`Account.Server` implements the interaction between multiple accounts, for instance when a transfer operations happens, the `Account.Server` that holds the data of the sender account, calls the `Account.Server` that holds the data of the recipient account.