defmodule AshDiagram.ClarityContent.ArchitectureDiagramTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityContent.ArchitectureDiagram
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain

  test "name" do
    assert ArchitectureDiagram.name() == "Architecture Diagram"
  end

  test "description" do
    assert ArchitectureDiagram.description() == "C4-style architecture diagram showing system structure"
  end

  test "applies to application with domains" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    assert ArchitectureDiagram.applies?(vertex, nil)
  end

  test "does not apply to application without domains" do
    vertex = %Vertex.Application{app: :no_ash_app, description: "", version: ""}
    refute ArchitectureDiagram.applies?(vertex, nil)
  end

  test "applies to domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    assert ArchitectureDiagram.applies?(vertex, nil)
  end

  test "does not apply to resource" do
    vertex = %Vertex.Ash.Resource{resource: AshDiagram.Flow.User}
    refute ArchitectureDiagram.applies?(vertex, nil)
  end

  test "does not apply to other vertex types" do
    refute ArchitectureDiagram.applies?(%{}, nil)
  end

  test "generates mermaid content for application" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    assert {:mermaid, content} = ArchitectureDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "C4Context")
  end

  test "generates mermaid content for domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    assert {:mermaid, content} = ArchitectureDiagram.render_static(vertex, nil)
    assert String.starts_with?(content, "C4Context")
  end
end
