defmodule Mix.AshDiagram do
  @moduledoc false

  # The `mix ash_diagram.*` tasks use this module. It replaces `Mix.Mermaid`
  # in Ash. It renders through `AshDiagram.render/2`, never through a shell.

  @render_formats %{"svg" => :svg, "pdf" => :pdf, "png" => :png}
  @formats ~w[plain md] ++ Map.keys(@render_formats)
  @mermaid_config "mermaidConfig.json"

  # Each image starts `mmdc` and a headless Chrome, or calls the mermaid.ink
  # web service, so only a few run at the same time.
  @render_concurrency 2

  @doc false
  @spec formats_doc() :: String.t()
  def formats_doc do
    """
    ## Formats

      * `plain` - the Mermaid source in a `.mmd` file. This is the default.
      * `md` - the Mermaid source in a Markdown code block, in a `.md` file.
      * `svg`, `pdf` or `png` - an image from `AshDiagram.render/2`.

    ## Images

    The image formats need a renderer. The task uses the first one of these:

      1. The renderer in `config :ash_diagram, :renderer`.
      2. `AshDiagram.Renderer.CLI`, when `:ex_cmd` is a dependency and `mmdc`
         is on the `PATH`. This renderer works on your machine.

    When neither is available, the task stops. It never selects the
    third-party mermaid.ink web service by itself, because that service gets
    a copy of each diagram. To use mermaid.ink, set:

        config :ash_diagram, :renderer, AshDiagram.Renderer.MermaidInk

    Set the renderer in `config/config.exs` or in an environment file such as
    `config/dev.exs`. The task does not load `config/runtime.exs`, because
    that file often needs the secrets of a running system.

    The task renders at most #{@render_concurrency} images at the same time.
    When `mermaidConfig.json` is in the current directory, the task gives it
    to the renderer. Only `AshDiagram.Renderer.CLI` reads it. The Ash task
    fits a PDF to the diagram, but this task does not.
    """
  end

  @doc false
  @spec domains() :: [module()]
  def domains, do: Ash.Info.domains(Mix.Project.config()[:app])

  @doc false
  @spec only(opts :: keyword()) :: [Path.t()] | nil
  def only(opts) do
    case Keyword.get_values(opts, :only) do
      [] -> nil
      paths -> Enum.map(paths, &Path.expand/1)
    end
  end

  @doc false
  @spec source(module :: module()) :: Path.t()
  def source(module) do
    case module.module_info(:compile)[:source] do
      nil ->
        Mix.raise("""
        The source file of #{inspect(module)} is not known, so the task cannot \
        name its diagram file. This occurs when the code is compiled with the \
        Erlang `deterministic` option. Remove that option, for example from \
        ERL_COMPILER_OPTIONS, and compile again.
        """)

      source ->
        to_string(source)
    end
  end

  @doc false
  @spec select(modules :: [module()], only :: [Path.t()] | nil) :: [module()]
  def select(modules, only) do
    selected = Enum.filter(modules, &selected?(&1, only))

    if only != nil and selected == [] do
      Mix.shell().info("No module is in the files that --only gives: #{Enum.join(only, ", ")}")
    end

    selected
  end

  @doc false
  @spec selected?(module :: module(), only :: [Path.t()] | nil) :: boolean()
  def selected?(_module, nil), do: true
  def selected?(module, only), do: Path.expand(source(module)) in only

  @doc false
  @spec validate_format!(format :: String.t()) :: String.t()
  def validate_format!(format) when format in @formats, do: format

  def validate_format!(format) do
    Mix.raise("""
    Invalid format `#{format}`.
    Valid options are #{Enum.map_join(@formats, ", ", &"`#{&1}`")}.
    """)
  end

  @doc false
  @spec file(source :: Path.t(), suffix :: String.t(), extension :: String.t()) :: Path.t()
  def file(source, suffix, extension) do
    filename = Path.rootname(Path.basename(source)) <> "-" <> suffix <> "." <> extension

    source
    |> Path.dirname()
    |> Path.join(filename)
  end

  # Writes one diagram for each module, and returns the paths in the order of
  # `modules`. `build` gives the diagram of a module and the message to print.
  # A module that is in `modules` more than once gets one file. When a diagram
  # fails, or two modules get the same file, the function still writes the
  # others. Then it raises one error that contains every failure.
  @doc false
  @spec write_all(
          modules :: [module()],
          suffix :: String.t(),
          format :: String.t(),
          build :: (module() -> {AshDiagram.t(), String.t()})
        ) :: [Path.t()]
  def write_all(modules, suffix, format, build) do
    check_renderer!(format)

    {jobs, conflicts} =
      modules
      |> Enum.uniq()
      |> Enum.map(&{&1, file(source(&1), suffix, extension(format))})
      |> split_conflicts()

    options = render_options(format)

    results =
      jobs
      |> Task.async_stream(&write_one(&1, format, options, build),
        timeout: :infinity,
        max_concurrency: concurrency(format)
      )
      |> Enum.map(fn {:ok, result} -> result end)

    case conflicts ++ for({:error, message} <- results, do: message) do
      [] -> for {:ok, path} <- results, do: path
      errors -> Mix.raise(Enum.join(errors, "\n\n"))
    end
  end

  # `AshDiagram.Renderer` selects mermaid.ink when no local renderer is
  # available. mermaid.ink is a third-party service, so the tasks send a
  # diagram there only when the config selects it.
  @spec check_renderer!(format :: String.t()) :: :ok
  defp check_renderer!(format) when is_map_key(@render_formats, format) do
    cond do
      match?({:ok, _renderer}, Application.fetch_env(:ash_diagram, :renderer)) ->
        :ok

      local_renderer?() ->
        :ok

      true ->
        Mix.raise("""
        No local renderer is available for the `#{format}` format.

        The task does not send your diagrams to the third-party mermaid.ink web
        service, unless your config selects it. Do one of these:

          * To render on your machine, add `:ex_cmd` to your dependencies and
            install `mmdc` (npm install -g @mermaid-js/mermaid-cli). Make sure
            that `mmdc` is on the PATH.

          * To render with mermaid.ink, add this line to config/config.exs:

                config :ash_diagram, :renderer, AshDiagram.Renderer.MermaidInk
        """)
    end
  end

  defp check_renderer!(_format), do: :ok

  @spec local_renderer?() :: boolean()
  defp local_renderer? do
    cli = AshDiagram.Renderer.CLI
    Code.ensure_loaded?(cli) and cli.supported?()
  end

  # For example, two modules in one source file get the same diagram file. If
  # both wrote to it at the same time, one diagram would be lost. So neither
  # module is written, and each conflict becomes an error message.
  @spec split_conflicts(jobs :: [{module(), Path.t()}]) :: {[{module(), Path.t()}], [String.t()]}
  defp split_conflicts(jobs) do
    by_path =
      Enum.group_by(jobs, fn {_module, path} -> path end, fn {module, _path} -> module end)

    {unique, shared} =
      Enum.split_with(jobs, fn {_module, path} -> match?([_module], by_path[path]) end)

    errors =
      shared
      |> Enum.map(fn {_module, path} -> path end)
      |> Enum.uniq()
      |> Enum.map(fn path ->
        """
        The task did not write #{path}, because more than one module gets \
        this file name: #{Enum.map_join(by_path[path], ", ", &inspect/1)}. The \
        file name comes from the source file name, so `--only` cannot separate \
        these modules. Put each module in its own source file.\
        """
      end)

    {unique, errors}
  end

  @spec write_one(
          job :: {module(), Path.t()},
          format :: String.t(),
          options :: AshDiagram.Renderer.options(),
          build :: (module() -> {AshDiagram.t(), String.t()})
        ) :: {:ok, Path.t()} | {:error, String.t()}
  # sobelow_skip ["Traversal.FileModule"]
  defp write_one({module, path}, format, options, build) do
    {diagram, message} = build.(module)
    File.write!(path, content(format, diagram, options))
    Mix.shell().info(message <> " (#{path})")
    {:ok, path}
  catch
    # Also an exit or a throw, so that one failure cannot stop the task.
    kind, reason ->
      {:error,
       "The task could not write the diagram of #{inspect(module)} to #{path}:\n" <>
         Exception.format(kind, reason, __STACKTRACE__)}
  end

  @spec extension(format :: String.t()) :: String.t()
  defp extension("plain"), do: "mmd"
  defp extension(format), do: format

  @spec concurrency(format :: String.t()) :: pos_integer()
  defp concurrency(format) when is_map_key(@render_formats, format), do: @render_concurrency
  defp concurrency(_format), do: System.schedulers_online()

  @spec render_options(format :: String.t()) :: AshDiagram.Renderer.options()
  defp render_options(format) when is_map_key(@render_formats, format) do
    [format: Map.fetch!(@render_formats, format)] ++ config_file_option()
  end

  defp render_options(_format), do: []

  @spec content(
          format :: String.t(),
          diagram :: AshDiagram.t(),
          options :: AshDiagram.Renderer.options()
        ) :: iodata()
  defp content("plain", diagram, _options), do: AshDiagram.compose(diagram)
  defp content("md", diagram, _options), do: AshDiagram.compose_markdown(diagram)
  defp content(_format, diagram, options), do: AshDiagram.render(diagram, options)

  # Ash passes `mermaidConfig.json` to `mmdc` when it is in the current
  # directory. Only `AshDiagram.Renderer.CLI` reads the option.
  @spec config_file_option() :: AshDiagram.Renderer.options()
  defp config_file_option do
    if File.exists?(@mermaid_config) do
      [config_file: Path.expand(@mermaid_config)]
    else
      []
    end
  end
end
