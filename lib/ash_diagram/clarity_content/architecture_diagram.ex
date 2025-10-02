with {:module, Clarity.Content} <- Code.ensure_loaded(Clarity.Content) do
  defmodule AshDiagram.ClarityContent.ArchitectureDiagram do
    @moduledoc """
    Content provider for Architecture diagrams of Ash applications and domains.
    """

    @behaviour Clarity.Content

    alias AshDiagram.Data.Architecture
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Domain

    @impl Clarity.Content
    def name, do: "Architecture Diagram"

    @impl Clarity.Content
    def description, do: "C4-style architecture diagram showing system structure"

    @impl Clarity.Content
    def applies?(%Vertex.Application{app: app}, _lens) do
      app
      |> Ash.Info.domains()
      |> case do
        [] -> false
        _domains -> true
      end
    end

    def applies?(%Domain{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Application{app: app}, _lens) do
      [app]
      |> Architecture.for_applications(show_private?: true)
      |> AshDiagram.C4.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end

    def render_static(%Domain{domain: domain}, _lens) do
      [domain]
      |> Architecture.for_domains(show_private?: true)
      |> AshDiagram.C4.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end
  end
end
