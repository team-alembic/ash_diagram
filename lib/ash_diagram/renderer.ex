defmodule AshDiagram.Renderer do
  @moduledoc """
  Behaviour for rendering AshDiagram diagrams.
  """

  @default_renderers [AshDiagram.Renderer.CLI, AshDiagram.Renderer.MermaidInk]

  @type theme() :: :default | :forest | :dark | :neutral
  @type format() :: :svg | :png | :pdf
  @type dimension() :: pos_integer()
  @type color() :: String.t()

  @type option() ::
          {:theme, theme()}
          | {:format, format()}
          | {:width, dimension()}
          | {:height, dimension()}
          | {:background_color, color()}
          | {:config_file, Path.t()}
          | {:svg_id, String.t()}
          | {:scale, float()}
          | {:puppeteer_config_file, Path.t()}
          | {:icon_packs, [String.t()]}
  @type options() :: [option()]

  @doc """
  Determine if the current environment supports this renderer.
  """
  @callback supported?() :: boolean()

  @doc """
  Render the diagram to the specified format.
  """
  @callback render(diagram :: iodata(), options :: options()) :: iodata()

  @doc """
  Render the diagram to the specified format, using the configured renderer.
  """
  @spec render(diagram :: iodata(), options :: options()) :: iodata()
  def render(diagram, options \\ []) do
    choose_renderer().render(diagram, options)
  end

  @spec choose_renderer() :: module()
  defp choose_renderer do
    case Application.fetch_env(:ash_diagram, :renderer) do
      {:ok, renderer} when is_atom(renderer) -> renderer
      _ -> detect_supported_renderer()
    end
  end

  @spec detect_supported_renderer() :: module()
  defp detect_supported_renderer do
    Enum.find(@default_renderers, fn renderer ->
      with {:module, ^renderer} <- Code.ensure_compiled(renderer),
           true <- function_exported?(renderer, :supported?, 0) do
        renderer.supported?()
      else
        _ -> false
      end
    end) || raise "No supported renderer found. Please configure a renderer in your application."
  end
end
