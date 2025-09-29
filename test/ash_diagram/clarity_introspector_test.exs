defmodule AshDiagram.ClarityIntrospectorTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityIntrospector
  alias AshDiagram.Flow.Domain
  alias AshDiagram.Flow.User
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Content

  describe inspect(&ClarityIntrospector.source_vertex_types/0) do
    test "returns correct source vertex types" do
      types = ClarityIntrospector.source_vertex_types()
      assert types == [Application, Domain, Resource]
    end
  end

  describe inspect(&ClarityIntrospector.introspect_vertex/2) do
    test "resource vertex generates policy diagram" do
      resource_vertex = %Resource{resource: User}
      result = ClarityIntrospector.introspect_vertex(resource_vertex, nil)

      assert {:ok,
              [
                {:vertex, policy_vertex},
                {:edge, ^resource_vertex, policy_vertex, :content}
              ]} = result

      assert %Content{name: "Policy Diagram", content: {:mermaid, _}} = policy_vertex
      assert policy_vertex.id == "policy_diagram_#{User}"
    end

    test "domain vertex generates class, ER, and architecture diagrams" do
      domain_vertex = %Domain{domain: AshDiagram.Flow.Domain}
      result = ClarityIntrospector.introspect_vertex(domain_vertex, nil)

      assert {:ok,
              [
                {:vertex, er_vertex},
                {:vertex, class_vertex},
                {:vertex, arch_vertex},
                {:edge, ^domain_vertex, er_vertex, :content},
                {:edge, ^domain_vertex, class_vertex, :content},
                {:edge, ^domain_vertex, arch_vertex, :content}
              ]} = result

      assert %Content{name: "ER Diagram", content: {:mermaid, _}} = er_vertex
      assert %Content{name: "Class Diagram", content: {:mermaid, _}} = class_vertex
      assert %Content{name: "Architecture Diagram", content: {:mermaid, _}} = arch_vertex

      domain_name = "#{AshDiagram.Flow.Domain}"
      assert er_vertex.id == "er_diagram_#{domain_name}"
      assert class_vertex.id == "class_diagram_#{domain_name}"
      assert arch_vertex.id == "architecture_diagram_#{domain_name}"
    end

    test "application vertex generates ER, class, and architecture diagrams" do
      app_vertex = %Application{app: :ash_diagram, description: "Test app", version: "1.0.0"}
      result = ClarityIntrospector.introspect_vertex(app_vertex, nil)

      assert {:ok,
              [
                {:vertex, er_vertex},
                {:vertex, class_vertex},
                {:vertex, arch_vertex},
                {:edge, ^app_vertex, er_vertex, :content},
                {:edge, ^app_vertex, class_vertex, :content},
                {:edge, ^app_vertex, arch_vertex, :content}
              ]} = result

      assert %Content{name: "ER Diagram", content: {:mermaid, _}} = er_vertex
      assert %Content{name: "Class Diagram", content: {:mermaid, _}} = class_vertex
      assert %Content{name: "Architecture Diagram", content: {:mermaid, _}} = arch_vertex

      assert er_vertex.id == "er_diagram_ash_diagram"
      assert class_vertex.id == "class_diagram_ash_diagram"
      assert arch_vertex.id == "architecture_diagram_ash_diagram"
    end

    test "application vertex with no Ash domains returns empty list" do
      app_vertex = %Application{app: :no_ash_app, description: "Test app", version: "1.0.0"}
      result = ClarityIntrospector.introspect_vertex(app_vertex, nil)
      assert result == {:ok, []}
    end
  end
end
