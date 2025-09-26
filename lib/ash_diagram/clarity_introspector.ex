case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule AshDiagram.ClarityIntrospector do
      @moduledoc """
      Clarity introspector for generating AshDiagram diagrams.

      This introspector generates various diagram types for Ash applications:
      - Entity Relationship diagrams at application and domain levels
      - Class diagrams at application and domain levels
      - Architecture diagrams at application and domain levels
      - Policy diagrams at resource level
      """

      @behaviour Clarity.Introspector

      alias AshDiagram.Data.Architecture
      alias AshDiagram.Data.Class
      alias AshDiagram.Data.EntityRelationship
      alias AshDiagram.Data.Policy
      alias AshDiagram.Flowchart
      alias Clarity.Vertex
      alias Clarity.Vertex.Ash.Resource

      @impl Clarity.Introspector
      def dependencies, do: [Clarity.Introspector.Application, Clarity.Introspector.Ash.Domain]

      @impl Clarity.Introspector
      def introspect(graph) do
        # Add diagrams for applications with Ash domains
        for %Vertex.Application{app: app} = app_vertex <- :digraph.vertices(graph),
            [] != Ash.Info.domains(app) do
          add_application_diagrams(graph, app_vertex, app)
        end

        # Add diagrams for Ash domains
        for %Vertex.Ash.Domain{domain: domain} = domain_vertex <- :digraph.vertices(graph) do
          add_domain_diagrams(graph, domain_vertex, domain)
        end

        # Add diagrams for Ash resources
        for %Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph) do
          add_resource_diagrams(graph, resource_vertex, resource)
        end

        graph
      end

      # Generate diagrams for applications
      @spec add_application_diagrams(:digraph.graph(), Vertex.Application.t(), Application.app()) ::
              :ok
      defp add_application_diagrams(graph, app_vertex, app) do
        # ER Diagram
        content_er_vertex = %Vertex.Content{
          id: "er_diagram_#{app}",
          name: "ER Diagram",
          content: {:mermaid, fn -> generate_app_er_diagram(app) end}
        }

        :digraph.add_vertex(graph, content_er_vertex)
        :digraph.add_edge(graph, app_vertex, content_er_vertex, :content)

        # Class Diagram
        content_class_vertex = %Vertex.Content{
          id: "class_diagram_#{app}",
          name: "Class Diagram",
          content: {:mermaid, fn -> generate_app_class_diagram(app) end}
        }

        :digraph.add_vertex(graph, content_class_vertex)
        :digraph.add_edge(graph, app_vertex, content_class_vertex, :content)

        # Architecture Diagram
        content_arch_vertex = %Vertex.Content{
          id: "architecture_diagram_#{app}",
          name: "Architecture Diagram",
          content: {:mermaid, fn -> generate_app_architecture_diagram(app) end}
        }

        :digraph.add_vertex(graph, content_arch_vertex)
        :digraph.add_edge(graph, app_vertex, content_arch_vertex, :content)
      end

      # Generate diagrams for domains
      @spec add_domain_diagrams(:digraph.graph(), Vertex.Ash.Domain.t(), Ash.Domain.t()) :: :ok
      defp add_domain_diagrams(graph, domain_vertex, domain) do
        # ER Diagram
        content_er_vertex = %Vertex.Content{
          id: "er_diagram_#{domain}",
          name: "ER Diagram",
          content: {:mermaid, fn -> generate_domain_er_diagram(domain) end}
        }

        :digraph.add_vertex(graph, content_er_vertex)
        :digraph.add_edge(graph, domain_vertex, content_er_vertex, :content)

        # Class Diagram
        content_class_vertex = %Vertex.Content{
          id: "class_diagram_#{domain}",
          name: "Class Diagram",
          content: {:mermaid, fn -> generate_domain_class_diagram(domain) end}
        }

        :digraph.add_vertex(graph, content_class_vertex)
        :digraph.add_edge(graph, domain_vertex, content_class_vertex, :content)

        # Architecture Diagram
        content_arch_vertex = %Vertex.Content{
          id: "architecture_diagram_#{domain}",
          name: "Architecture Diagram",
          content: {:mermaid, fn -> generate_domain_architecture_diagram(domain) end}
        }

        :digraph.add_vertex(graph, content_arch_vertex)
        :digraph.add_edge(graph, domain_vertex, content_arch_vertex, :content)
      end

      # Generate diagrams for resources
      @spec add_resource_diagrams(:digraph.graph(), Resource.t(), Ash.Resource.t()) :: :ok
      defp add_resource_diagrams(graph, resource_vertex, resource) do
        # Policy Diagram
        content_policy_vertex = %Vertex.Content{
          id: "policy_diagram_#{resource}",
          name: "Policy Diagram",
          content: {:mermaid, fn -> generate_resource_policy_diagram(resource) end}
        }

        :digraph.add_vertex(graph, content_policy_vertex)
        :digraph.add_edge(graph, resource_vertex, content_policy_vertex, :content)
      end

      # Generate Mermaid content for application ER diagram
      @spec generate_app_er_diagram(Application.app()) :: String.t()
      defp generate_app_er_diagram(app) do
        [app]
        |> EntityRelationship.for_applications()
        |> AshDiagram.EntityRelationship.compose()
        |> IO.iodata_to_binary()
      end

      # Generate Mermaid content for application class diagram
      @spec generate_app_class_diagram(Application.app()) :: String.t()
      defp generate_app_class_diagram(app) do
        [app]
        |> Class.for_applications()
        |> AshDiagram.Class.compose()
        |> IO.iodata_to_binary()
      end

      # Generate Mermaid content for application architecture diagram
      @spec generate_app_architecture_diagram(Application.app()) :: String.t()
      defp generate_app_architecture_diagram(app) do
        [app]
        |> Architecture.for_applications()
        |> AshDiagram.C4.compose()
        |> IO.iodata_to_binary()
      end

      # Generate Mermaid content for domain ER diagram
      @spec generate_domain_er_diagram(Ash.Domain.t()) :: String.t()
      defp generate_domain_er_diagram(domain) do
        [domain]
        |> EntityRelationship.for_domains()
        |> AshDiagram.EntityRelationship.compose()
        |> IO.iodata_to_binary()
      end

      # Generate Mermaid content for domain class diagram
      @spec generate_domain_class_diagram(Ash.Domain.t()) :: String.t()
      defp generate_domain_class_diagram(domain) do
        [domain]
        |> Class.for_domains()
        |> AshDiagram.Class.compose()
        |> IO.iodata_to_binary()
      end

      # Generate Mermaid content for domain architecture diagram
      @spec generate_domain_architecture_diagram(Ash.Domain.t()) :: String.t()
      defp generate_domain_architecture_diagram(domain) do
        [domain]
        |> Architecture.for_domains()
        |> AshDiagram.C4.compose()
        |> IO.iodata_to_binary()
      end

      # Generate Mermaid content for resource policy diagram
      @spec generate_resource_policy_diagram(Ash.Resource.t()) :: String.t()
      defp generate_resource_policy_diagram(resource) do
        resource
        |> Policy.for_resource()
        |> Flowchart.compose()
        |> IO.iodata_to_binary()
      end
    end

  _ ->
    defmodule AshDiagram.ClarityIntrospector do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def dependencies, do: [Clarity.Introspector.Application, Clarity.Introspector.Ash.Domain]

      @impl Clarity.Introspector
      def introspect(graph), do: graph
    end
end
