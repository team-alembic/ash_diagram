defmodule AshDiagram.ClarityContent.ErDiagramTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityContent.ErDiagram
  alias AshDiagram.Flow.User
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  test "name" do
    assert ErDiagram.name() == "ER Diagram"
  end

  test "description" do
    assert ErDiagram.description() == "Entity Relationship diagram showing data model structure"
  end

  test "applies to application with domains" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    assert ErDiagram.applies?(vertex, nil)
  end

  test "does not apply to application without domains" do
    vertex = %Vertex.Application{app: :no_ash_app, description: "", version: ""}
    refute ErDiagram.applies?(vertex, nil)
  end

  test "applies to domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    assert ErDiagram.applies?(vertex, nil)
  end

  test "applies to resource" do
    vertex = %Resource{resource: User}
    assert ErDiagram.applies?(vertex, nil)
  end

  test "does not apply to other vertex types" do
    refute ErDiagram.applies?(%{}, nil)
  end

  test "generates mermaid content for application" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    assert {:mermaid, content} = ErDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "erDiagram")
  end

  test "generates mermaid content for domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    assert {:mermaid, content} = ErDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "erDiagram")
  end

  test "generates mermaid content for resource" do
    vertex = %Resource{resource: User}
    assert {:mermaid, content} = ErDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "erDiagram")
  end
end
