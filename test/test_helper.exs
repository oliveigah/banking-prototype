Account.System.start_link()
ExUnit.start()
ExUnit.after_suite(fn _ -> File.rm_rf("./persist") end)
