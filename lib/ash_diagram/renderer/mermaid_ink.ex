with {:module, Req} <- Code.ensure_compiled(Req) do
  defmodule AshDiagram.Renderer.MermaidInk do
    @moduledoc """
    Renderer for Mermaid diagrams using [mermaid.ink](https://mermaid.ink) web
    service.

    > #### Mix Dependency {: .warning}
    >
    > This renderer requires the optional dependency `:req` to be included in
    > your `mix.exs` file.

    > #### Mermaid Ink Service {: .warning}
    >
    > mermaid.ink is a third-party service that renders Mermaid diagrams.
    >
    > * Ensure you understand the privacy implications of using this service.
    > * Be aware that the service may have usage limits or availability issues.
    > * Be a good citizen and do not overload the service with excessive
    >   requests.
    """

    @behaviour AshDiagram.Renderer

    @doc false
    @impl AshDiagram.Renderer
    def supported?, do: true

    @doc false
    @impl AshDiagram.Renderer
    def render(diagram, options) do
      uri = URI.new!("https://mermaid.ink/img/#{encode(diagram)}")

      uri =
        case Keyword.get(options, :format, :jpeg) do
          :jpeg -> URI.append_query(uri, "type=jpeg")
          :png -> URI.append_query(uri, "type=png")
          :webp -> URI.append_query(uri, "type=webp")
          :svg -> URI.append_path(uri, "svg")
          :pdf -> URI.append_path(uri, "pdf")
        end

      uri =
        case Keyword.fetch(options, :background_color) do
          {:ok, color} -> URI.append_query(uri, "bgColor=#{color}")
          :error -> uri
        end

      uri =
        Enum.reduce([:width, :height, :scale, :theme], uri, fn option, acc ->
          passthrough_options(acc, options, option)
        end)

      %Req.Response{status: 200, body: body} = Req.get!(uri)
      body
    end

    @spec encode(diagram :: iodata()) :: String.t()
    defp encode(diagram) do
      json = JSON.encode!(%{code: IO.iodata_to_binary(diagram)})

      z = :zlib.open()
      :ok = :zlib.deflateInit(z, :best_compression)

      compressed =
        IO.iodata_to_binary([
          :zlib.deflate(z, json),
          :zlib.deflate(z, [], :finish)
        ])

      :ok = :zlib.deflateEnd(z)
      :ok = :zlib.close(z)

      "pako:" <> Base.url_encode64(compressed, padding: false)
    end

    @spec passthrough_options(
            uri :: URI.t(),
            options :: AshDiagram.Renderer.options(),
            option :: atom()
          ) :: URI.t()
    defp passthrough_options(uri, options, option) do
      case Keyword.fetch(options, option) do
        {:ok, value} -> URI.append_query(uri, to_string(option) <> "=" <> to_string(value))
        :error -> uri
      end
    end
  end
end
