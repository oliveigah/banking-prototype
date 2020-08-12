defmodule Helpers do
  @moduledoc false

  @special_fields [:currency, :type, :current_currency, :new_currency]
  defp convert_special_values_to_atoms(%{} = body) do
    @special_fields
    |> Enum.reduce(body, fn field, final_body ->
      special_value = Map.get(body, field)

      if special_value !== nil do
        Map.put(final_body, field, String.to_atom(special_value))
      else
        final_body
      end
    end)
  end

  def parse_body_request(%{} = map) do
    map
    |> Map.new(fn {k, v} -> {String.to_atom(k), parse_body_request(v)} end)
    |> convert_special_values_to_atoms
  end

  def parse_body_request([_ | _] = list) do
    list
    |> Enum.map(&parse_body_request/1)
  end

  def parse_body_request(value) do
    value
  end

  def parse_body_response(%{} = map) do
    map
    |> Map.new(fn {k, v} -> {String.to_atom(k), parse_body_response(v)} end)
  end

  def parse_body_response([_ | _] = list) do
    list
    |> Enum.map(&parse_body_response/1)
  end

  def parse_body_response(value) do
    value
  end

  def validate_body(required_fields_spec, parsed_body, key_prefix \\ "")

  def validate_body(%{} = required_fields_spec, %{} = parsed_body, key_prefix) do
    required_fields_spec
    |> Stream.map(fn {template_key, template_value} ->
      body_value = Map.get(parsed_body, template_key, make_ref())

      if is_function(template_value) do
        {"#{key_prefix}.#{template_key}", template_value.(body_value)}
      else
        validate_body(template_value, body_value, template_key)
      end
    end)
    |> Enum.map(&process_validation_list/1)
    |> List.flatten()
    |> Enum.filter(&(&1 !== nil))
    |> Enum.map(&remove_initial_dot/1)
  end

  def validate_body(%{} = required_fields_spec, nil, key_prefix) do
    required_fields_spec
    |> Enum.map(fn {template_key, _} ->
      {"#{key_prefix}.#{template_key}", false}
    end)
  end

  defp remove_initial_dot(string) do
    if String.starts_with?(string, ".") do
      {_, new_string} =
        String.to_charlist(string)
        |> List.pop_at(0)

      List.to_string(new_string)
    else
      string
    end
  end

  defp process_validation_list({path, false}) do
    path
  end

  defp process_validation_list({_path, true}) do
    nil
  end

  defp process_validation_list([_ | _] = entry) do
    Enum.map(entry, &process_validation_list/1)
  end

  defp process_validation_list(path) do
    path
  end

  def is_date_between(date, date_ini, date_fin) do
    ini_diff = Date.diff(date, date_ini)
    fin_diff = Date.diff(date, date_fin)
    ini_diff >= 0 && fin_diff <= 0
  end

  def reset_account_system() do
    # Get the pids of all currently alive processes
    accounts_used_pids =
      DynamicSupervisor.which_children(Account.Cache)
      |> Stream.map(fn entry ->
        case entry do
          {_, pid, :worker, [Account.Server]} -> pid
          _ -> nil
        end
      end)
      |> Enum.filter(fn ele -> ele !== nil end)

    # Terminate all processes
    Enum.each(accounts_used_pids, &Process.exit(&1, :clean_up))

    # Reset the "database"
    base_folder = Application.get_env(:banking, :database_base_folder)
    File.rm_rf(base_folder)
    :ok
  end
end
