defmodule AshDiagram.ClarityIntrospectorTest do
  use ExUnit.Case, async: true

  alias AshDiagram.ClarityIntrospector
  alias AshDiagram.Flow.Domain
  alias AshDiagram.Flow.User
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  describe inspect(&ClarityIntrospector.dependencies/2) do
    test "returns correct dependencies" do
      deps = ClarityIntrospector.dependencies()
      assert deps == [Clarity.Introspector.Application, Clarity.Introspector.Ash.Domain]
    end
  end

  describe inspect(&ClarityIntrospector.introspect/2) do
    setup do
      graph = :digraph.new()

      {:ok, graph: graph}
    end

    test "processes empty graph without errors", %{graph: graph} do
      initial_vertices = :digraph.vertices(graph)
      result = ClarityIntrospector.introspect(graph)

      assert :digraph.vertices(result) == initial_vertices
    end

    test "resource vertex generates policy diagram", %{graph: graph} do
      resource_vertex = %Resource{resource: User}
      :digraph.add_vertex(graph, resource_vertex, resource_vertex)

      ClarityIntrospector.introspect(graph)

      vertices = :digraph.vertices(graph)
      assert length(vertices) == 2

      assert %Vertex.Content{name: "Policy Diagram", content: {:mermaid, _}} =
               policy_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "policy_diagram_" <> _}, &1))

      assert [^resource_vertex, ^policy_vertex] = :digraph.get_short_path(graph, resource_vertex, policy_vertex)
    end

    test "domain vertex generates class, ER, and architecture diagrams", %{graph: graph} do
      domain_vertex = %Domain{domain: Domain}
      :digraph.add_vertex(graph, domain_vertex, domain_vertex)

      ClarityIntrospector.introspect(graph)

      vertices = :digraph.vertices(graph)
      assert length(vertices) == 4

      domain_name = "#{Domain}"

      assert %Vertex.Content{name: "ER Diagram", content: {:mermaid, _}} =
               er_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "er_diagram_" <> ^domain_name}, &1))

      assert %Vertex.Content{name: "Class Diagram", content: {:mermaid, _}} =
               class_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "class_diagram_" <> ^domain_name}, &1))

      assert %Vertex.Content{name: "Architecture Diagram", content: {:mermaid, _}} =
               arch_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "architecture_diagram_" <> ^domain_name}, &1))

      assert [^domain_vertex, ^er_vertex] = :digraph.get_short_path(graph, domain_vertex, er_vertex)
      assert [^domain_vertex, ^class_vertex] = :digraph.get_short_path(graph, domain_vertex, class_vertex)
      assert [^domain_vertex, ^arch_vertex] = :digraph.get_short_path(graph, domain_vertex, arch_vertex)
    end

    test "application vertex generates ER, class, and architecture diagrams", %{graph: graph} do
      app_vertex = %Vertex.Application{app: :ash_diagram, description: "Test app", version: "1.0.0"}
      :digraph.add_vertex(graph, app_vertex, app_vertex)

      ClarityIntrospector.introspect(graph)

      vertices = :digraph.vertices(graph)
      assert length(vertices) == 4

      assert %Vertex.Content{name: "ER Diagram", content: {:mermaid, _}} =
               er_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "er_diagram_ash_diagram"}, &1))

      assert %Vertex.Content{name: "Class Diagram", content: {:mermaid, _}} =
               class_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "class_diagram_ash_diagram"}, &1))

      assert %Vertex.Content{name: "Architecture Diagram", content: {:mermaid, _}} =
               arch_vertex =
               Enum.find(vertices, &match?(%Vertex.Content{id: "architecture_diagram_ash_diagram"}, &1))

      assert [^app_vertex, ^er_vertex] = :digraph.get_short_path(graph, app_vertex, er_vertex)
      assert [^app_vertex, ^class_vertex] = :digraph.get_short_path(graph, app_vertex, class_vertex)
      assert [^app_vertex, ^arch_vertex] = :digraph.get_short_path(graph, app_vertex, arch_vertex)
    end
  end
end
