defmodule Mix.Tasks.AshDiagram.GenerateResourceDiagrams do
  @shortdoc "Generates a Mermaid resource diagram for each Ash domain"

  @moduledoc """
  #{@shortdoc}.

  This task replaces `mix ash.generate_resource_diagrams`. It takes the same
  options, and it writes the same files, next to the source file of each
  domain. It reads the domains from `config :my_app, :ash_domains`.

  ## Command line options

    * `--type` - `class`, `er` or `architecture`. Defaults to `class`.
      `architecture` writes a C4 diagram.
    * `--only` - generates only for the domain in the given source file.
      Repeat the option for more than one domain.
    * `--format` - one of:
      * `plain` - the Mermaid source in a `.mmd` file. This is the default.
      * `md` - the Mermaid source in a Markdown code block, in a `.md` file.
      * `svg`, `pdf` or `png` - an image from `AshDiagram.render/2`.

  ## Images

  `svg`, `pdf` and `png` use the renderer that `AshDiagram.Renderer` selects.
  When `mmdc` is not on the `PATH` and `:req` is a dependency, that renderer
  is the third-party mermaid.ink web service. To keep your diagrams on your
  machine, set:

      config :ash_diagram, :renderer, AshDiagram.Renderer.CLI

  When `mermaidConfig.json` is in the current directory, the task gives it
  to the renderer. Only `AshDiagram.Renderer.CLI` reads it.

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
    Mix.Task.run("compile")

    {opts, _args} =
      OptionParser.parse!(argv,
        strict: [only: :keep, type: :string, format: :string],
        aliases: [o: :only, t: :type, f: :format]
      )

    {creator, suffix, label} = type!(Keyword.get(opts, :type, "class"))
    format = opts |> Keyword.get(:format, "plain") |> Mix.AshDiagram.validate_format!()
    only = Mix.AshDiagram.only(opts)

    Mix.AshDiagram.domains()
    |> Enum.filter(&Mix.AshDiagram.selected?(&1, only))
    |> Task.async_stream(
      fn domain ->
        Mix.AshDiagram.write_diagram(
          Mix.AshDiagram.source(domain),
          suffix,
          format,
          creator.for_domains([domain]),
          "Generated #{label} for #{inspect(domain)}"
        )
      end,
      timeout: :infinity
    )
    |> Stream.run()
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
