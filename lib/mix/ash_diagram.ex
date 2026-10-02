defmodule Mix.AshDiagram do
  @moduledoc false

  # Shared by the `mix ash_diagram.*` tasks. It replaces `Mix.Mermaid` in Ash,
  # but it renders through `AshDiagram.render/2`, never through a shell.

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

    The image formats use the renderer that `AshDiagram.Renderer` selects:

      1. The renderer in `config :ash_diagram, :renderer`, when it is set.
      2. `AshDiagram.Renderer.CLI`, when `:ex_cmd` is a dependency and
         `mmdc` is on the `PATH`.
      3. `AshDiagram.Renderer.MermaidInk`, when `:req` is a dependency. This
         renderer sends the diagram to the third-party mermaid.ink web
         service.

    To keep your diagrams on your machine, add `:ex_cmd` to your
    dependencies, install `mmdc`, and set:

        config :ash_diagram, :renderer, AshDiagram.Renderer.CLI

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
        name its diagram file. Compile the project without the Erlang \
        `deterministic` option, for example in ERL_COMPILER_OPTIONS.
        """)

      source ->
        to_string(source)
    end
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
  # fails, the others are still written, then the function raises with every
  # error.
  @doc false
  @spec write_all(
          modules :: [module()],
          suffix :: String.t(),
          format :: String.t(),
          build :: (module() -> {AshDiagram.t(), String.t()})
        ) :: [Path.t()]
  def write_all(modules, suffix, format, build) do
    jobs =
      modules
      |> Enum.uniq()
      |> Enum.map(&{&1, file(source(&1), suffix, extension(format))})
      |> check_conflicts!()

    options = render_options(format)

    results =
      jobs
      |> Task.async_stream(&write_one(&1, format, options, build),
        timeout: :infinity,
        max_concurrency: concurrency(format)
      )
      |> Enum.map(fn {:ok, result} -> result end)

    case for {:error, message} <- results, do: message do
      [] -> for {:ok, path} <- results, do: path
      errors -> Mix.raise(Enum.join(errors, "\n\n"))
    end
  end

  # Two modules in one source file, for example, would write to the same file
  # at the same time, and one diagram would be lost.
  @spec check_conflicts!(jobs :: [{module(), Path.t()}]) :: [{module(), Path.t()}]
  defp check_conflicts!(jobs) do
    conflicts =
      jobs
      |> Enum.group_by(fn {_module, path} -> path end, fn {module, _path} -> module end)
      |> Enum.filter(&match?({_path, [_first, _second | _rest]}, &1))

    if conflicts != [] do
      Mix.raise("""
      More than one module writes to the same diagram file:

      #{Enum.map_join(conflicts, "\n", fn {path, modules} -> "  #{path}: #{Enum.map_join(modules, ", ", &inspect/1)}" end)}

      Put each module in its own source file.
      """)
    end

    jobs
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
  rescue
    error ->
      {:error,
       "Could not write the diagram of #{inspect(module)} to #{path}:\n" <>
         Exception.message(error)}
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
