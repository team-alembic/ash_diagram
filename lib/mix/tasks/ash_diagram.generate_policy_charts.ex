defmodule Mix.Tasks.AshDiagram.GeneratePolicyCharts do
  @shortdoc "Generates a Mermaid flowchart of the policies of each Ash resource"

  @moduledoc """
  #{@shortdoc}.

  This task replaces `mix ash.generate_policy_charts`. It takes the same
  options, and it gives each file the same name, next to the source file of
  each resource. It reads the resources of the domains in
  `config :my_app, :ash_domains`, and it skips each resource that does not
  use `Ash.Policy.Authorizer`.

  ## Command line options

    * `--only` - generates only for the resource in the given source file.
      Repeat the option for more than one resource. The path is relative to
      the current directory. In an umbrella project, the task runs in the
      directory of each app, so give the path relative to the app directory.
    * `--all` - generates for every resource. Give `--only` or `--all`.
    * `--format` - `plain`, `md`, `svg`, `pdf` or `png`. Defaults to `plain`.
      See "Formats".

  #{Mix.AshDiagram.formats_doc()}
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
    {opts, _args} =
      OptionParser.parse!(argv,
        strict: [only: :keep, all: :boolean, format: :string],
        aliases: [o: :only, f: :format, a: :all]
      )

    only = Mix.AshDiagram.only(opts)

    if is_nil(only) and not Keyword.get(opts, :all, false) do
      Mix.raise("Give the `--only` option or the `--all` option.")
    end

    format = opts |> Keyword.get(:format, "plain") |> Mix.AshDiagram.validate_format!()

    # The options are validated first, so that a usage error shows before a
    # long compile. The task does not run "app.config", because
    # config/runtime.exs often needs the secrets of a running system.
    Mix.Task.run("compile")

    Mix.AshDiagram.domains()
    |> Enum.flat_map(&Info.resources/1)
    |> Enum.filter(&(Authorizer in Spark.extensions(&1)))
    |> Mix.AshDiagram.select(only)
    |> Mix.AshDiagram.write_all("policy-flowchart", format, fn resource ->
      {Policy.for_resource(resource), "Generated Mermaid Flow Chart for #{inspect(resource)}"}
    end)
  end
end
