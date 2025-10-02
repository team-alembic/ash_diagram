with {:module, Clarity.Content} <- Code.ensure_loaded(Clarity.Content) do
  defmodule AshDiagram.ClarityContent.ErDiagram do
    @moduledoc """
    Content provider for Entity Relationship diagrams of Ash applications and domains.
    """

    @behaviour Clarity.Content

    alias AshDiagram.Data.EntityRelationship
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "ER Diagram"

    @impl Clarity.Content
    def description, do: "Entity Relationship diagram showing data model structure"

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
    def applies?(%Resource{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Application{app: app}, _lens) do
      [app]
      |> EntityRelationship.for_applications(show_private?: true)
      |> AshDiagram.EntityRelationship.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end

    def render_static(%Domain{domain: domain}, _lens) do
      [domain]
      |> EntityRelationship.for_domains(show_private?: true)
      |> AshDiagram.EntityRelationship.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end

    def render_static(%Resource{resource: resource}, _lens) do
      [resource]
      |> EntityRelationship.for_resources(show_private?: true)
      |> AshDiagram.EntityRelationship.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end
  end
end
