defmodule AshDiagram.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :ash_diagram,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      name: "AshDiagram",
      description:
        "AshDiagram is a library for generating beautiful, interactive diagrams to visualize your Ash Framework applications.",
      source_url: "https://github.com/team-alembic/ash_diagram",
      package: package(),
      docs: &docs/0
    ]
  end

  defp elixirc_paths(env)
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      env: [
        clarity_introspectors: [AshDiagram.ClarityIntrospector]
      ]
    ]
  end

  defp deps do
    # styler:sort
    [
      {:ash, "~> 3.5 and >= 3.5.34"},
      {:clarity, "~> 0.2.0", optional: true},
      # Development
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctest_formatter, "~> 0.4.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.18", only: [:dev, :test]},
      {:ex_check, "~> 0.15", only: [:dev, :test]},
      {:ex_cmd, "~> 0.16.0", optional: true},
      {:ex_doc, "~> 0.38.2", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.4", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:picosat_elixir, "~> 0.2.3", only: [:dev, :test]},
      {:req, "~> 0.5.15", optional: true},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Alembic Pty Ltd"],
      files: [
        "lib",
        "LICENSE*",
        "mix.exs",
        "README*"
      ],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/team-alembic/ash_diagram"}
    ]
  end

  defp docs do
    [
      main: "AshDiagram",
      source_ref: "v#{@version}",
      groups_for_modules: [
        "Generation / Introspection": ~r/AshDiagram\.Data(\..*)?$/,
        "Diagram / ER": ~r/AshDiagram\.EntityRelationship(\..*)?$/,
        "Diagram / Class": ~r/AshDiagram\.Class(\..*)?$/,
        "Diagram / C4": ~r/AshDiagram\.C4(\..*)?$/,
        "Diagram / Flowchart": ~r/AshDiagram\.Flowchart(\..*)?$/,
        Renderers: ~r/AshDiagram\.Renderer(\..*)?$/
      ],
      logo: "logos/logo.svg",
      assets: %{"logos" => "logos"}
    ]
  end
end
