defmodule Banking.Application do
  use Application

  def start(_, _) do
    Banking.System.start_link()
  end
end
