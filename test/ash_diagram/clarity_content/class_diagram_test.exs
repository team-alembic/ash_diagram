defmodule AshDiagram.ClarityContent.ClassDiagramTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityContent.ClassDiagram
  alias AshDiagram.Flow.User
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  test "name" do
    assert ClassDiagram.name() == "Class Diagram"
  end

  test "description" do
    assert ClassDiagram.description() == "Class diagram showing resource structure and relationships"
  end

  test "applies to application with domains" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    assert ClassDiagram.applies?(vertex, nil)
  end

  test "does not apply to application without domains" do
    vertex = %Vertex.Application{app: :no_ash_app, description: "", version: ""}
    refute ClassDiagram.applies?(vertex, nil)
  end

  test "applies to domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    assert ClassDiagram.applies?(vertex, nil)
  end

  test "applies to resource" do
    vertex = %Resource{resource: User}
    assert ClassDiagram.applies?(vertex, nil)
  end

  test "does not apply to other vertex types" do
    refute ClassDiagram.applies?(%{}, nil)
  end

  test "generates mermaid content for application" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    assert {:mermaid, content} = ClassDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "classDiagram")
  end

  test "generates mermaid content for domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    assert {:mermaid, content} = ClassDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "classDiagram")
  end

  test "generates mermaid content for resource" do
    vertex = %Resource{resource: User}
    assert {:mermaid, content} = ClassDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "classDiagram")
  end
end
