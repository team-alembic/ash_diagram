defmodule AshDiagram.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_diagram,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: &docs/0
    ]
  end

  defp elixirc_paths(env)
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    # styler:sort
    [
      {:ash, "~> 3.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctest_formatter, "~> 0.4.0", only: [:dev, :test], runtime: false},
      {:ex_cmd, "~> 0.15.0", optional: true},
      {:ex_doc, "~> 0.38.2", only: [:dev, :test], runtime: false},
      {:picosat_elixir, "~> 0.2.3", only: [:dev, :test]},
      {:req, "~> 0.5.15", optional: true},
      {:styler, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md"],
      groups_for_modules: [
        "Diagram / ER": ~r/AshDiagram\.EntityRelationship(\..*)?$/,
        "Diagram / C4": ~r/AshDiagram\.C4(\..*)?$/,
        Renderers: ~r/AshDiagram\.Renderer(\..*)?$/
      ]
    ]
  end
end
