defmodule Mix.Tasks.AshDiagram.GeneratePolicyCharts do
  @shortdoc "Generates a Mermaid flowchart of the policies of each Ash resource"

  @moduledoc """
  #{@shortdoc}.

  This task replaces `mix ash.generate_policy_charts`. It takes the same
  options, and it writes the same files, next to the source file of each
  resource. It reads the resources of the domains in
  `config :my_app, :ash_domains`, and it skips each resource that does not
  use `Ash.Policy.Authorizer`.

  ## Command line options

    * `--only` - generates only for the resource in the given source file.
      Repeat the option for more than one resource.
    * `--all` - generates for every resource. Give `--only` or `--all`.
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

      mix ash_diagram.generate_policy_charts --all
      mix ash_diagram.generate_policy_charts --only lib/my_app/accounts/user.ex --format svg
  """

  use Mix.Task

  alias Ash.Domain.Info
  alias Ash.Policy.Authorizer
  alias AshDiagram.Data.Policy

  @recursive true

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("compile")

    {opts, _args} =
      OptionParser.parse!(argv,
        strict: [only: :keep, all: :boolean, format: :string],
        aliases: [o: :only, f: :format, a: :all]
      )

    only = Mix.AshDiagram.only(opts)

    if is_nil(only) and not Keyword.get(opts, :all, false) do
      Mix.raise("Must pass the `--only` option or the `--all` option.")
    end

    format = opts |> Keyword.get(:format, "plain") |> Mix.AshDiagram.validate_format!()

    Mix.AshDiagram.domains()
    |> Enum.flat_map(&Info.resources/1)
    |> Enum.filter(&(Authorizer in Spark.extensions(&1) and Mix.AshDiagram.selected?(&1, only)))
    |> Task.async_stream(
      fn resource ->
        Mix.AshDiagram.write_diagram(
          Mix.AshDiagram.source(resource),
          "policy-flowchart",
          format,
          Policy.for_resource(resource),
          "Generated Mermaid Flow Chart for #{inspect(resource)}"
        )
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end
end
