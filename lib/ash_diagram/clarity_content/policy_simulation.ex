with {:module, Clarity.Content} <- Code.ensure_loaded(Clarity.Content) do
  defmodule AshDiagram.ClarityContent.PolicySimulation do
    @moduledoc """
    Content provider for Policy Simulation diagrams of Ash resources and elements.

    Renders interactive flowcharts showing step-by-step policy authorization logic
    for resources, actions, policies, and fields.
    """

    @behaviour Clarity.Content

    alias AshDiagram.Data.PolicySimulation
    alias AshDiagram.Flowchart
    alias Clarity.Vertex.Ash.Action
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Policy
    alias Clarity.Vertex.Ash.Relationship
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Policy Simulation"

    @impl Clarity.Content
    def description, do: "Interactive flowchart showing step-by-step policy authorization logic"

    @impl Clarity.Content
    def applies?(%Resource{}, _lens), do: true
    def applies?(%Action{}, _lens), do: true
    def applies?(%Policy{}, _lens), do: true
    def applies?(%Attribute{}, _lens), do: true
    def applies?(%Calculation{}, _lens), do: true
    def applies?(%Relationship{}, _lens), do: true
    def applies?(%Aggregate{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(vertex, _lens) do
      vertex
      |> generate_policy_simulation()
      |> Flowchart.compose()
      |> IO.iodata_to_binary()
      |> then(&{:mermaid, &1})
    end

    @spec generate_policy_simulation(
            Resource.t()
            | Action.t()
            | Policy.t()
            | Attribute.t()
            | Calculation.t()
            | Relationship.t()
            | Aggregate.t()
          ) :: Flowchart.t()
    defp generate_policy_simulation(%Resource{resource: resource}) do
      PolicySimulation.for_resource(resource)
    end

    defp generate_policy_simulation(%Action{resource: resource, action: action}) do
      PolicySimulation.for_action(resource, action)
    end

    defp generate_policy_simulation(%Policy{resource: resource, policy: policy}) do
      PolicySimulation.for_policies(resource, [policy])
    end

    defp generate_policy_simulation(%Attribute{
           resource: resource,
           attribute: %{name: field_name}
         }) do
      PolicySimulation.for_field(resource, field_name)
    end

    defp generate_policy_simulation(%Calculation{
           resource: resource,
           calculation: %{name: field_name}
         }) do
      PolicySimulation.for_field(resource, field_name)
    end

    defp generate_policy_simulation(%Relationship{
           resource: resource,
           relationship: %{name: field_name}
         }) do
      PolicySimulation.for_field(resource, field_name)
    end

    defp generate_policy_simulation(%Aggregate{
           resource: resource,
           aggregate: %{name: field_name}
         }) do
      PolicySimulation.for_field(resource, field_name)
    end
  end
end
