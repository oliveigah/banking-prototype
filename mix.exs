defmodule Banking.MixProject do
  use Mix.Project

  def project do
    [
      app: :banking,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Banking Prototype",
      source_url: "https://github.com/oliveigah/banking_prototype",
      homepage_url: "https://oliveigah.github.io/banking_prototype",
      docs: [
        # The main page in the docs
        main: "readme",
        logo: "logo.png",
        extras: [
          "./README.md"
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Banking.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:cowboy, "~> 2.8"},
      {:plug_cowboy, "~> 2.3"},
      {:poison, "~> 4.0"}
    ]
  end
end
