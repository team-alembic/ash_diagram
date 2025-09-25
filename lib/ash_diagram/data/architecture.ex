defmodule AshDiagram.Data.Architecture do
  @moduledoc """
  Provides functions to create Architecture Diagrams for Ash applications.

  This module generates C4 context diagrams that visualize Ash application architecture
  with nested boundaries organized by OTP applications:

  - **BEAM VM**: Root boundary containing all OTP applications
  - **OTP Applications**: Individual applications (like `:ash`, `:my_app`)
  - **Domains**: Ash domains within user applications
  - **Resources**: Individual Ash resources within domains
  - **Data Layers**: Data storage systems organized by their OTP application

  ## Architecture Hierarchy

  ```
  BEAM
  ├── ash (OTP Application)
  │   └── Mnesia (Data Layer)
  ├── my_app (OTP Application)
  │   └── Blog (Domain)
  │       ├── User (Resource)
  │       └── Post (Resource)
  └── External Systems
      └── PostgreSQL (External Data Layer)
  ```

  ## Data Layer Organization

  Data layers are automatically placed in the correct OTP application boundary
  using `Application.get_application/1`. For example:
  - `Ash.DataLayer.Mnesia` → `:ash` application
  - `AshPostgres.DataLayer` → `:ash_postgres` application

  ## Example

      # Generate an architecture diagram for resources
      diagram = AshDiagram.Data.Architecture.for_resources([MyApp.User, MyApp.Post])

      # Generate for domains or applications
      diagram = AshDiagram.Data.Architecture.for_domains([MyApp.Blog])
      diagram = AshDiagram.Data.Architecture.for_applications([:my_app])

  """

  alias Ash.Domain.Info
  alias Ash.Resource.Relationships
  alias AshDiagram.C4
  alias AshDiagram.C4.Boundary
  alias AshDiagram.C4.Element
  alias AshDiagram.C4.Relationship
  alias AshDiagram.Data.Extension

  @type option() ::
          {:name, :full | :short}
          | {:show_private?, boolean()}
          | {:title, String.t()}

  @type options() :: [option()]

  @default_options [
    name: :short,
    show_private?: false,
    title: nil
  ]

  @spec for_applications(applications :: [Application.app()], options :: options()) ::
          AshDiagram.t()
  def for_applications(applications, options \\ []),
    do: applications |> Enum.flat_map(&Ash.Info.domains/1) |> for_domains(options)

  @spec for_domains(domains :: [Ash.Domain.t()], options :: options()) :: AshDiagram.t()
  def for_domains(domains, options \\ []),
    do: domains |> Enum.flat_map(&Info.resources/1) |> for_resources(options)

  @spec for_resources(resources :: [Ash.Resource.t()], options :: options()) :: AshDiagram.t()
  def for_resources(resources, options \\ []) do
    options = Keyword.merge(@default_options, options)

    entity_names = build_entity_names(resources, options[:name])
    access_functions = build_access_functions(options[:show_private?])

    entries = build_context_entries(resources, entity_names, access_functions)
    title = build_title(resources, options)

    extensions = collect_extensions(resources)

    Extension.construct_diagram(__MODULE__, extensions, %C4{
      type: :c4_context,
      title: title,
      entries: entries
    })
  end

  @spec build_entity_names(resources :: [Ash.Resource.t()], name_option :: :full | :short) :: %{
          Ash.Resource.t() => iodata()
        }
  defp build_entity_names(resources, :full) do
    Map.new(resources, &{&1, inspect(&1)})
  end

  defp build_entity_names(resources, :short) do
    common_name_parts = common_prefix(resources)

    Map.new(resources, fn resource ->
      module_parts = Module.split(resource)
      dropped_parts = Enum.drop(module_parts, length(common_name_parts))

      shortened_name =
        case dropped_parts do
          [] -> List.last(module_parts) || inspect(resource)
          parts -> Enum.intersperse(parts, ".")
        end

      {resource, shortened_name}
    end)
  end

  @spec build_access_functions(show_private? :: boolean()) ::
          {function(), function(), function(), function()}
  defp build_access_functions(true) do
    {&Ash.Resource.Info.attributes/1, &Ash.Resource.Info.calculations/1,
     &Ash.Resource.Info.aggregates/1, &Ash.Resource.Info.relationships/1}
  end

  defp build_access_functions(false) do
    {&Ash.Resource.Info.public_attributes/1, &Ash.Resource.Info.public_calculations/1,
     &Ash.Resource.Info.public_aggregates/1, &Ash.Resource.Info.public_relationships/1}
  end

  @spec build_context_entries(
          resources :: [Ash.Resource.t()],
          entity_names :: %{Ash.Resource.t() => iodata()},
          access_functions :: {function(), function(), function(), function()}
        ) :: [C4.entry()]
  defp build_context_entries(resources, entity_names, access_functions) do
    # Build the root boundary containing all OTP applications
    root_boundary = build_root_boundary(resources, entity_names)
    relationships = build_nested_relationships(resources, entity_names, access_functions)

    [root_boundary] ++ relationships
  end

  @spec build_root_boundary(
          resources :: [Ash.Resource.t()],
          entity_names :: %{Ash.Resource.t() => iodata()}
        ) :: Boundary.t()
  defp build_root_boundary(resources, entity_names) do
    # Get all data layers and group them by their OTP application
    data_layer_apps = get_data_layer_applications(resources)

    # Build OTP application boundaries (including data layer apps like :ash)
    all_apps = Enum.uniq(get_application_names(resources) ++ data_layer_apps)

    otp_app_boundaries = build_all_otp_application_boundaries(all_apps, resources, entity_names)

    # Build external boundaries (shared across all applications)
    external_boundaries = build_external_boundaries(resources)

    # Collect all sub-boundaries
    sub_boundaries = otp_app_boundaries ++ external_boundaries

    %Boundary{
      type: :system_boundary,
      alias: "beam",
      label: "BEAM",
      entries: sub_boundaries
    }
  end

  @spec build_all_otp_application_boundaries(
          apps :: [atom()],
          resources :: [Ash.Resource.t()],
          entity_names :: %{Ash.Resource.t() => iodata()}
        ) :: [Boundary.t()]
  defp build_all_otp_application_boundaries(apps, resources, entity_names) do
    Enum.map(apps, fn otp_app ->
      app_resources = Enum.filter(resources, &(Application.get_application(&1) == otp_app))

      entries =
        cond do
          otp_app == :ash ->
            # For :ash app, include data layers that belong to it
            build_ash_app_entries(resources)

          length(app_resources) > 0 ->
            # For user apps, include domains with resources
            build_domain_boundaries(app_resources, entity_names)

          true ->
            # Empty app (shouldn't happen but just in case)
            []
        end

      %Boundary{
        type: :system_boundary,
        alias: to_string(otp_app),
        label: "#{otp_app} Application",
        entries: entries
      }
    end)
  end

  @spec build_ash_app_entries(resources :: [Ash.Resource.t()]) :: [Element.t()]
  defp build_ash_app_entries(resources) do
    # Get data layers that belong to :ash application
    ash_data_layers =
      resources
      |> Enum.map(&Ash.Resource.Info.data_layer/1)
      |> Enum.uniq()
      |> Enum.filter(fn data_layer ->
        Application.get_application(data_layer) == :ash
      end)

    Enum.map(ash_data_layers, fn data_layer ->
      data_layer_name = data_layer_name(data_layer)

      %Element{
        type: :system_db,
        external?: false,
        alias: String.downcase(data_layer_name),
        label: data_layer_name,
        description: data_layer_name
      }
    end)
  end

  @spec build_domain_boundaries(
          resources :: [Ash.Resource.t()],
          entity_names :: %{Ash.Resource.t() => iodata()}
        ) :: [Boundary.t()]
  defp build_domain_boundaries(resources, entity_names) do
    domains = resources |> Enum.map(&Ash.Resource.Info.domain/1) |> Enum.uniq()

    Enum.map(domains, fn domain ->
      domain_resources = Enum.filter(resources, &(Ash.Resource.Info.domain(&1) == domain))

      resource_elements =
        Enum.map(domain_resources, fn resource ->
          %Element{
            type: :system,
            external?: false,
            alias: module_alias(resource),
            label: entity_names[resource],
            description: build_resource_description(resource)
          }
        end)

      %Boundary{
        type: :system_boundary,
        alias: module_alias(domain),
        label: domain_label(domain),
        entries: resource_elements
      }
    end)
  end

  @spec build_external_boundaries(resources :: [Ash.Resource.t()]) :: [Boundary.t()]
  defp build_external_boundaries(resources) do
    # Get data layers that don't belong to any known OTP application
    external_data_layers =
      resources
      |> Enum.map(&Ash.Resource.Info.data_layer/1)
      |> Enum.uniq()
      |> Enum.filter(fn data_layer ->
        Application.get_application(data_layer) == nil
      end)

    if Enum.empty?(external_data_layers) do
      []
    else
      external_elements =
        Enum.map(external_data_layers, fn data_layer ->
          data_layer_name = data_layer_name(data_layer)

          %Element{
            type: :system_db,
            external?: true,
            alias: String.downcase(data_layer_name),
            label: data_layer_name,
            description: "#{data_layer_name} (external)"
          }
        end)

      [
        %Boundary{
          type: :system_boundary,
          alias: "external",
          label: "External Systems",
          entries: external_elements
        }
      ]
    end
  end

  @spec build_resource_relationship(
          relationship :: Relationships.relationship(),
          entity_names :: %{Ash.Resource.t() => iodata()}
        ) :: Relationship.t()
  defp build_resource_relationship(
         %{source: source, destination: destination} = relationship,
         _entity_names
       ) do
    %Relationship{
      type: :rel,
      from: module_alias(source),
      to: module_alias(destination),
      label: relationship_label(relationship),
      description: relationship_description(relationship)
    }
  end

  @spec collect_extensions(resources :: [Ash.Resource.t()]) :: [module()]
  defp collect_extensions(resources) do
    resource_extensions = Enum.flat_map(resources, &Ash.Resource.Info.extensions/1)

    domain_extensions =
      resources
      |> Enum.map(&Ash.Resource.Info.domain/1)
      |> Enum.flat_map(&Info.extensions/1)

    Enum.uniq(resource_extensions ++ domain_extensions)
  end

  @spec build_title(resources :: [Ash.Resource.t()], options :: options()) :: iodata()
  defp build_title(_resources, options) do
    options[:title] || []
  end

  @spec build_nested_relationships(
          resources :: [Ash.Resource.t()],
          entity_names :: %{Ash.Resource.t() => iodata()},
          access_functions :: {function(), function(), function(), function()}
        ) :: [Relationship.t()]
  defp build_nested_relationships(resources, entity_names, {_, _, _, relationship_fun}) do
    # Resource-to-resource relationships
    resource_relationships =
      resources
      |> Enum.flat_map(relationship_fun)
      |> Enum.sort()
      |> Enum.map(&build_resource_relationship(&1, entity_names))
      |> Enum.uniq()

    # Resource-to-data-layer relationships
    data_relationships =
      Enum.map(resources, fn resource ->
        data_layer = Ash.Resource.Info.data_layer(resource)
        data_layer_name = data_layer |> data_layer_name() |> String.downcase()

        %Relationship{
          type: :rel,
          from: module_alias(resource),
          to: data_layer_name,
          label: "uses",
          description: "Stores data"
        }
      end)

    resource_relationships ++ data_relationships
  end

  # Helper functions for naming and descriptions

  @spec get_application_names([Ash.Resource.t()]) :: [atom()]
  defp get_application_names(resources) do
    resources
    |> Enum.map(&Application.get_application/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @spec get_data_layer_applications([Ash.Resource.t()]) :: [atom()]
  defp get_data_layer_applications(resources) do
    resources
    |> Enum.map(&Ash.Resource.Info.data_layer/1)
    |> Enum.map(&Application.get_application/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @spec module_alias(module()) :: String.t()
  defp module_alias(module) do
    module
    |> Macro.underscore()
    |> String.replace("/", "_")
  end

  @spec domain_label(Ash.Domain.t()) :: String.t()
  defp domain_label(domain) do
    domain
    |> Module.split()
    |> List.last()
  end

  @spec build_resource_description(Ash.Resource.t()) :: String.t()
  defp build_resource_description(resource) do
    action_count = length(Ash.Resource.Info.actions(resource))
    relationship_count = length(Ash.Resource.Info.relationships(resource))

    "Resource with #{action_count} actions, #{relationship_count} relationships"
  end

  @spec data_layer_name(module()) :: String.t()
  defp data_layer_name(Ash.DataLayer.Ets), do: "ETS"
  defp data_layer_name(Ash.DataLayer.Mnesia), do: "Mnesia"

  defp data_layer_name(data_layer) do
    data_layer
    |> Module.split()
    |> List.last()
    |> String.replace("DataLayer", "")
  end

  @spec relationship_label(Relationships.relationship()) :: String.t()
  defp relationship_label(%{name: name}), do: to_string(name)

  @spec relationship_description(Relationships.relationship()) :: String.t()
  defp relationship_description(%{type: type}), do: "#{type} relationship"

  @spec common_prefix([module()]) :: [String.t()]
  defp common_prefix([]), do: []

  defp common_prefix(parts) do
    parts
    |> Enum.map(&Module.split/1)
    |> Enum.reduce(fn list, acc ->
      acc
      |> Enum.zip(list)
      |> Enum.take_while(fn {a, b} -> a == b end)
      |> Enum.map(&elem(&1, 1))
    end)
  end
end
