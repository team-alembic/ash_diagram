with {:module, ExCmd} <- Code.ensure_compiled(ExCmd) do
  defmodule AshDiagram.Renderer.CLI do
    @moduledoc """
    Renders diagrams using the `mmdc` command line tool.

    > #### Mermaid Dependency {: .warning}
    >
    > This renderer requires the NPM package
    > [`@mermaid-js/mermaid-cli`](https://github.com/mermaid-js/mermaid-cli)
    > to be installed and available in your PATH.
    >
    > You can install it using:
    > ```bash
    > npm install -g @mermaid-js/mermaid-cli
    > ```

    > #### Mix Dependency {: .warning}
    >
    > This renderer requires the optional dependency `:ex_cmd` to be included in
    > your `mix.exs` file.
    """

    @behaviour AshDiagram.Renderer

    @doc false
    @impl AshDiagram.Renderer
    def supported? do
      System.find_executable("mmdc") != nil
    end

    @doc false
    @impl AshDiagram.Renderer
    def render(diagram, options) do
      case System.find_executable("mmdc") do
        nil ->
          raise "mmdc command not found. Please install @mermaid-js/mermaid-cli."

        mmdc_path ->
          args = build_args(options)

          [mmdc_path, "-i", "-", "-o", "-" | args]
          |> ExCmd.stream!(input: IO.iodata_to_binary(diagram))
          |> Enum.to_list()
      end
    end

    @spec build_args(options :: AshDiagram.Renderer.options()) :: [String.t()]
    defp build_args(options) do
      Enum.flat_map(options, fn
        {:theme, theme} -> ["-t", to_string(theme)]
        {:format, format} -> ["-e", to_string(format)]
        {:width, width} -> ["-w", Integer.to_string(width)]
        {:height, height} -> ["-H", Integer.to_string(height)]
        {:background_color, color} -> ["-b", color]
        {:config_file, path} -> ["-c", Path.expand(path)]
        {:svg_id, id} -> ["-I", id]
        {:scale, scale} -> ["-s", Float.to_string(scale)]
        {:puppeteer_config_file, path} -> ["-p", Path.expand(path)]
        {:icon_packs, packs} -> ["--iconPacks", Enum.join(packs, ",")]
      end)
    end
  end
end
