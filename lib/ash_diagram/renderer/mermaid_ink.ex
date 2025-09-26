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

    defmodule ServerError do
      @moduledoc false
      defexception [:response]

      @type t() :: %__MODULE__{
              __exception__: true,
              response: Req.Response.t()
            }

      @impl Exception
      def exception(opts), do: %__MODULE__{response: opts[:response]}

      @impl true
      def message(%__MODULE__{response: response}),
        do: "Mermaid.ink server error (#{response.status}): #{inspect(response.body)}"
    end

    defmodule UnknownResponseError do
      @moduledoc false
      defexception [:response]

      @type t() :: %__MODULE__{
              __exception__: true,
              response: Req.Response.t()
            }

      @impl Exception
      def exception(opts), do: %__MODULE__{response: opts[:response]}

      @impl true
      def message(%__MODULE__{response: response}),
        do: "Unexpected response from Mermaid.ink (#{response.status}): #{inspect(response.body)}"
    end

    @doc false
    @impl AshDiagram.Renderer
    def supported?, do: true

    @doc false
    @impl AshDiagram.Renderer
    def render(diagram, options) do
      diagram
      |> build_uri(options)
      |> Req.get!()
      |> handle_response()
    end

    @spec build_uri(diagram :: iodata(), options :: AshDiagram.Renderer.options()) :: URI.t()
    defp build_uri(diagram, options) do
      uri = URI.new!("https://mermaid.ink/img/#{encode(diagram)}")

      uri
      |> apply_format(options)
      |> apply_background_color(options)
      |> apply_passthrough_options(options)
    end

    @spec apply_format(uri :: URI.t(), options :: AshDiagram.Renderer.options()) :: URI.t()
    defp apply_format(uri, options) do
      case Keyword.get(options, :format, :jpeg) do
        :jpeg -> URI.append_query(uri, "type=jpeg")
        :png -> URI.append_query(uri, "type=png")
        :webp -> URI.append_query(uri, "type=webp")
        :svg -> URI.append_path(uri, "svg")
        :pdf -> URI.append_path(uri, "pdf")
      end
    end

    @spec apply_background_color(uri :: URI.t(), options :: AshDiagram.Renderer.options()) ::
            URI.t()
    defp apply_background_color(uri, options) do
      case Keyword.fetch(options, :background_color) do
        {:ok, color} -> URI.append_query(uri, "bgColor=#{color}")
        :error -> uri
      end
    end

    @spec apply_passthrough_options(uri :: URI.t(), options :: AshDiagram.Renderer.options()) ::
            URI.t()
    defp apply_passthrough_options(uri, options) do
      Enum.reduce([:width, :height, :scale, :theme], uri, fn option, acc ->
        passthrough_options(acc, options, option)
      end)
    end

    @spec handle_response(response :: Req.Response.t()) :: binary()
    defp handle_response(response) do
      case response do
        %Req.Response{status: 200, body: body} ->
          body

        %Req.Response{status: status} = response when status >= 500 and status < 600 ->
          raise ServerError, response: response

        %Req.Response{} = response ->
          raise UnknownResponseError, response: response
      end
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

      IO.iodata_to_binary(["pako:", Base.url_encode64(compressed, padding: false)])
    end

    @spec passthrough_options(
            uri :: URI.t(),
            options :: AshDiagram.Renderer.options(),
            option :: atom()
          ) :: URI.t()
    defp passthrough_options(uri, options, option) do
      case Keyword.fetch(options, option) do
        {:ok, value} ->
          URI.append_query(uri, IO.iodata_to_binary([to_string(option), "=", to_string(value)]))

        :error ->
          uri
      end
    end
  end
end
