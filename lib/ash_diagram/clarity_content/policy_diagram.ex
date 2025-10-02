with {:module, Clarity.Content} <- Code.ensure_loaded(Clarity.Content) do
  defmodule AshDiagram.ClarityContent.PolicyDiagram do
    @moduledoc """
    Content provider for Policy diagrams of Ash resources.
    """

    @behaviour Clarity.Content

    alias AshDiagram.Data.Policy
    alias AshDiagram.Flowchart
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Policy Diagram"

    @impl Clarity.Content
    def description, do: "Flowchart diagram showing resource authorization policies"

    @impl Clarity.Content
    def applies?(%Resource{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Resource{resource: resource}, _lens) do
      resource
      |> Policy.for_resource()
      |> Flowchart.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end
  end
end
