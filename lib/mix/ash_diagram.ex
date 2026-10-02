defmodule Mix.AshDiagram do
  @moduledoc false

  # Shared by the `mix ash_diagram.*` tasks. It replaces `Mix.Mermaid` in Ash,
  # but it renders through `AshDiagram.render/2`, never through a shell.

  @formats ~w[plain md svg pdf png]
  @render_formats %{"svg" => :svg, "pdf" => :pdf, "png" => :png}
  @mermaid_config "mermaidConfig.json"

  @doc false
  @spec domains() :: [module()]
  def domains do
    Application.get_env(Mix.Project.config()[:app], :ash_domains, [])
  end

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
  def source(module), do: to_string(module.module_info(:compile)[:source])

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
    Valid options are `plain`, `md`, `svg`, `pdf` or `png`.
    """)
  end

  @doc false
  @spec file(source :: Path.t() | charlist(), suffix :: String.t(), extension :: String.t()) ::
          Path.t()
  def file(source, suffix, extension) do
    source = to_string(source)
    filename = Path.rootname(Path.basename(source)) <> "-" <> suffix <> "." <> extension

    source
    |> Path.dirname()
    |> Path.join(filename)
  end

  @doc false
  @spec write_diagram(
          source :: Path.t(),
          suffix :: String.t(),
          format :: String.t(),
          diagram :: AshDiagram.t(),
          message :: String.t()
        ) :: Path.t()
  # sobelow_skip ["Traversal.FileModule"]
  def write_diagram(source, suffix, format, diagram, message) do
    path = file(source, suffix, extension(format))
    File.write!(path, content(format, diagram))
    Mix.shell().info(message <> " (#{path})")
    path
  end

  @spec extension(format :: String.t()) :: String.t()
  defp extension("plain"), do: "mmd"
  defp extension(format), do: format

  @spec content(format :: String.t(), diagram :: AshDiagram.t()) :: iodata()
  defp content("plain", diagram), do: AshDiagram.compose(diagram)
  defp content("md", diagram), do: AshDiagram.compose_markdown(diagram)

  defp content(format, diagram) do
    options = [format: Map.fetch!(@render_formats, format)] ++ config_file_option()
    AshDiagram.render(diagram, options)
  end

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
