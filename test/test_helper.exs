ExUnit.start()
base_folder = Application.get_env(:banking, :database_base_folder)
ExUnit.after_suite(fn _ -> File.rm_rf(base_folder) end)
