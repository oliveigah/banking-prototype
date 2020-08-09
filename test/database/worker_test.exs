defmodule DatabaseWorkerTest do
  use ExUnit.Case

  doctest Database

  test "sotorage process" do
    base_folder = Application.get_env(:banking, :database_base_folder)
    Database.Worker.start_link(1234)

    Database.Worker.store_sync(1234, "file_1", 1, "#{base_folder}test1")

    Database.Worker.store_sync(1234, 2, "value_2", "#{base_folder}test2")

    Database.Worker.store_sync(1234, 123, Account.new(), "#{base_folder}complex_test")

    assert File.exists?("#{base_folder}test1/file_1") === true
    assert File.exists?("#{base_folder}test2/2") === true
    assert File.exists?("#{base_folder}complex_test/123") === true

    result_1 = Database.Worker.get(1234, "file_1", "#{base_folder}test1")
    result_2 = Database.Worker.get(1234, 2, "#{base_folder}test2")
    result_3 = Database.Worker.get(1234, 123, "#{base_folder}complex_test")

    assert result_1 === 1
    assert result_2 === "value_2"
    assert result_3 === Account.new()
  end
end
