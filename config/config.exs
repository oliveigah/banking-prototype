import Config

config :banking, account_http_port: 3000

import_config("#{Mix.env()}.exs")
