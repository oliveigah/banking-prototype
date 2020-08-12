defmodule Banking.Application do
  @moduledoc false
  use Application

  def start(_, _) do
    Banking.System.start_link()
  end
end
