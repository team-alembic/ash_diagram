defmodule AshDiagram.ClarityIntrospector do
  @moduledoc false

  @behaviour Clarity.Introspector

  alias AshDiagram.Data.Architecture
  alias AshDiagram.Data.Class
  alias AshDiagram.Data.EntityRelationship
  alias AshDiagram.Data.Policy
  alias AshDiagram.Flowchart
  alias Clarity.Vertex.Application, as: ApplicationVertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Content

  @impl Clarity.Introspector
  def source_vertex_types, do: [ApplicationVertex, Domain, Resource]

  @impl Clarity.Introspector
  def introspect_vertex(%ApplicationVertex{app: app} = app_vertex, _graph) do
    entries =
      app
      |> Ash.Info.domains()
      |> case do
        [] ->
          []

        _domains ->
          # ER Diagram
          content_er_vertex = %Content{
            id: "er_diagram_#{app}",
            name: "ER Diagram",
            content: {:mermaid, fn -> generate_app_er_diagram(app) end}
          }

          # Class Diagram
          content_class_vertex = %Content{
            id: "class_diagram_#{app}",
            name: "Class Diagram",
            content: {:mermaid, fn -> generate_app_class_diagram(app) end}
          }

          # Architecture Diagram
          content_arch_vertex = %Content{
            id: "architecture_diagram_#{app}",
            name: "Architecture Diagram",
            content: {:mermaid, fn -> generate_app_architecture_diagram(app) end}
          }

          [
            {:vertex, content_er_vertex},
            {:vertex, content_class_vertex},
            {:vertex, content_arch_vertex},
            {:edge, app_vertex, content_er_vertex, :content},
            {:edge, app_vertex, content_class_vertex, :content},
            {:edge, app_vertex, content_arch_vertex, :content}
          ]
      end

    {:ok, entries}
  end

  def introspect_vertex(%Domain{domain: domain} = domain_vertex, _graph) do
    # ER Diagram
    content_er_vertex = %Content{
      id: "er_diagram_#{domain}",
      name: "ER Diagram",
      content: {:mermaid, fn -> generate_domain_er_diagram(domain) end}
    }

    # Class Diagram
    content_class_vertex = %Content{
      id: "class_diagram_#{domain}",
      name: "Class Diagram",
      content: {:mermaid, fn -> generate_domain_class_diagram(domain) end}
    }

    # Architecture Diagram
    content_arch_vertex = %Content{
      id: "architecture_diagram_#{domain}",
      name: "Architecture Diagram",
      content: {:mermaid, fn -> generate_domain_architecture_diagram(domain) end}
    }

    {:ok,
     [
       {:vertex, content_er_vertex},
       {:vertex, content_class_vertex},
       {:vertex, content_arch_vertex},
       {:edge, domain_vertex, content_er_vertex, :content},
       {:edge, domain_vertex, content_class_vertex, :content},
       {:edge, domain_vertex, content_arch_vertex, :content}
     ]}
  end

  def introspect_vertex(%Resource{resource: resource} = resource_vertex, _graph) do
    # Policy Diagram
    content_policy_vertex = %Content{
      id: "policy_diagram_#{resource}",
      name: "Policy Diagram",
      content: {:mermaid, fn -> generate_resource_policy_diagram(resource) end}
    }

    {:ok,
     [
       {:vertex, content_policy_vertex},
       {:edge, resource_vertex, content_policy_vertex, :content}
     ]}
  end

  # Generate Mermaid content for application ER diagram
  @spec generate_app_er_diagram(Application.app()) :: String.t()
  defp generate_app_er_diagram(app) do
    [app]
    |> EntityRelationship.for_applications(show_private?: true)
    |> AshDiagram.EntityRelationship.compose()
    |> IO.iodata_to_binary()
  end

  # Generate Mermaid content for application class diagram
  @spec generate_app_class_diagram(Application.app()) :: String.t()
  defp generate_app_class_diagram(app) do
    [app]
    |> Class.for_applications(show_private?: true)
    |> AshDiagram.Class.compose()
    |> IO.iodata_to_binary()
  end

  # Generate Mermaid content for application architecture diagram
  @spec generate_app_architecture_diagram(Application.app()) :: String.t()
  defp generate_app_architecture_diagram(app) do
    [app]
    |> Architecture.for_applications(show_private?: true)
    |> AshDiagram.C4.compose()
    |> IO.iodata_to_binary()
  end

  # Generate Mermaid content for domain ER diagram
  @spec generate_domain_er_diagram(Ash.Domain.t()) :: String.t()
  defp generate_domain_er_diagram(domain) do
    [domain]
    |> EntityRelationship.for_domains(show_private?: true)
    |> AshDiagram.EntityRelationship.compose()
    |> IO.iodata_to_binary()
  end

  # Generate Mermaid content for domain class diagram
  @spec generate_domain_class_diagram(Ash.Domain.t()) :: String.t()
  defp generate_domain_class_diagram(domain) do
    [domain]
    |> Class.for_domains(show_private?: true)
    |> AshDiagram.Class.compose()
    |> IO.iodata_to_binary()
  end

  # Generate Mermaid content for domain architecture diagram
  @spec generate_domain_architecture_diagram(Ash.Domain.t()) :: String.t()
  defp generate_domain_architecture_diagram(domain) do
    [domain]
    |> Architecture.for_domains(show_private?: true)
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
