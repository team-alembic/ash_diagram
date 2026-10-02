defmodule Mix.Tasks.AshDiagram.GenerateResourceDiagrams do
  @shortdoc "Generates a Mermaid resource diagram for each Ash domain"

  @moduledoc """
  #{@shortdoc}.

  This task replaces `mix ash.generate_resource_diagrams`. It takes the same
  options, and it gives each file the same name, next to the source file of
  each domain. It reads the domains from `config :my_app, :ash_domains`.

  ## Command line options

    * `--type` - `class`, `er` or `architecture`. Defaults to `class`.
      `architecture` writes a C4 diagram.
    * `--only` - generates only for the domain in the given source file.
      Repeat the option for more than one domain.
    * `--format` - `plain`, `md`, `svg`, `pdf` or `png`. Defaults to `plain`.
      See "Formats".

  #{Mix.AshDiagram.formats_doc()}
  ## Examples

      mix ash_diagram.generate_resource_diagrams
      mix ash_diagram.generate_resource_diagrams --type er --format svg
      mix ash_diagram.generate_resource_diagrams --only lib/my_app/accounts.ex
  """

  use Mix.Task

  alias AshDiagram.Data.Architecture
  alias AshDiagram.Data.Class
  alias AshDiagram.Data.EntityRelationship

  @recursive true

  @types %{
    "class" => {Class, "mermaid-class-diagram", "Class Diagram"},
    "er" => {EntityRelationship, "mermaid-er-diagram", "ER Diagram"},
    "architecture" => {Architecture, "mermaid-architecture-diagram", "Architecture Diagram"}
  }

  @impl Mix.Task
  def run(argv) do
    {opts, _args} =
      OptionParser.parse!(argv,
        strict: [only: :keep, type: :string, format: :string],
        aliases: [o: :only, t: :type, f: :format]
      )

    {creator, suffix, label} = type!(Keyword.get(opts, :type, "class"))
    format = opts |> Keyword.get(:format, "plain") |> Mix.AshDiagram.validate_format!()
    only = Mix.AshDiagram.only(opts)

    # The options are validated first, so that a usage error shows before a
    # long compile. "app.config" compiles the project and loads its config,
    # which can set the renderer.
    Mix.Task.run("app.config")

    Mix.AshDiagram.domains()
    |> Enum.filter(&Mix.AshDiagram.selected?(&1, only))
    |> Mix.AshDiagram.write_all(suffix, format, fn domain ->
      {creator.for_domains([domain]), "Generated #{label} for #{inspect(domain)}"}
    end)
  end

  @spec type!(type :: String.t()) :: {module(), String.t(), String.t()}
  defp type!(type) do
    case Map.fetch(@types, type) do
      {:ok, entry} ->
        entry

      :error ->
        Mix.raise("""
        Invalid resource diagram type `#{type}`.
        Valid options are `class`, `er` or `architecture`.
        """)
    end
  end
end
