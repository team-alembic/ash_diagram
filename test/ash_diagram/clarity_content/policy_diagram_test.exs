defmodule AshDiagram.ClarityContent.PolicyDiagramTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityContent.PolicyDiagram
  alias AshDiagram.Flow.User
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Resource

  test "name" do
    assert PolicyDiagram.name() == "Policy Diagram"
  end

  test "description" do
    assert PolicyDiagram.description() == "Flowchart diagram showing resource authorization policies"
  end

  test "applies to resource" do
    vertex = %Resource{resource: User}
    assert PolicyDiagram.applies?(vertex, nil)
  end

  test "does not apply to application" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    refute PolicyDiagram.applies?(vertex, nil)
  end

  test "does not apply to domain" do
    vertex = %Vertex.Ash.Domain{domain: AshDiagram.Flow.Domain}
    refute PolicyDiagram.applies?(vertex, nil)
  end

  test "does not apply to other vertex types" do
    refute PolicyDiagram.applies?(%{}, nil)
  end

  test "generates mermaid content for resource" do
    vertex = %Resource{resource: User}
    assert {:mermaid, content} = PolicyDiagram.render_static(vertex, nil)
    assert String.contains?(content, "flowchart")
  end
end
