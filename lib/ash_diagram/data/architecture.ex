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

  """

  alias Ash.Domain.Info
  alias Ash.Resource.Relationships
  alias AshDiagram.C4
  alias AshDiagram.C4.Boundary
  alias AshDiagram.C4.Element
  alias AshDiagram.C4.Relationship
  alias AshDiagram.Data.Extension

  @typedoc """
  Configuration option for architecture diagram generation.

  Available options:
  - `{:name, :full | :short}` - How to display resource names. `:full` shows complete module names, `:short` shows shortened names with common prefixes removed
  - `{:show_private?, boolean()}` - Whether to include private relationships in the diagram
  - `{:title, String.t()}` - Custom title for the diagram
  """
  @type option() ::
          {:name, :full | :short}
          | {:show_private?, boolean()}
          | {:title, String.t()}

  @typedoc """
  List of configuration options for architecture diagram generation.
  """
  @type options() :: [option()]

  @default_options [
    name: :short,
    show_private?: false,
    title: nil
  ]

  @doc """
  Generates an architecture diagram for the given OTP applications.

  Creates a C4 context diagram showing the architecture hierarchy of Ash applications
  within the specified OTP applications. All domains from the applications are included.

  ## Parameters

  - `applications` - List of OTP application names (e.g., `[:my_app, :other_app]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate diagram for a single application
      AshDiagram.Data.Architecture.for_applications([:my_app])

      # Generate diagram with full module names
      AshDiagram.Data.Architecture.for_applications([:my_app], name: :full)

      # Include private resources and relationships
      AshDiagram.Data.Architecture.for_applications([:my_app], show_private?: true)

  """
  @spec for_applications(applications :: [Application.app()], options :: options()) ::
          AshDiagram.t()
  def for_applications(applications, options \\ []),
    do: applications |> Enum.flat_map(&Ash.Info.domains/1) |> for_domains(options)

  @doc """
  Generates an architecture diagram for the given Ash domains.

  Creates a C4 context diagram showing the architecture hierarchy for all resources
  within the specified domains.

  ## Parameters

  - `domains` - List of Ash domain modules (e.g., `[MyApp.Blog, MyApp.Accounts]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate diagram for specific domains
      AshDiagram.Data.Architecture.for_domains([MyApp.Blog, MyApp.Accounts])

      # Generate diagram with a custom title
      AshDiagram.Data.Architecture.for_domains([MyApp.Blog], title: "Blog Domain Architecture")

  """
  @spec for_domains(domains :: [Ash.Domain.t()], options :: options()) :: AshDiagram.t()
  def for_domains(domains, options \\ []),
    do: domains |> Enum.flat_map(&Info.resources/1) |> for_resources(options)

  @doc """
  Generates an architecture diagram for the given Ash resources.

  Creates a C4 context diagram showing the complete architecture hierarchy including:
  - BEAM VM as the root boundary
  - OTP applications containing the resources and their data layers
  - Domain boundaries within applications
  - Resources within domains
  - Data layer connections
  - Resource relationships

  ## Parameters

  - `resources` - List of Ash resource modules (e.g., `[MyApp.User, MyApp.Post]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate diagram for specific resources
      AshDiagram.Data.Architecture.for_resources([MyApp.User, MyApp.Post])

      # Use full module names and show private relationships
      AshDiagram.Data.Architecture.for_resources(
        [MyApp.User, MyApp.Post],
        name: :full,
        show_private?: true
      )

      # Add a custom title
      AshDiagram.Data.Architecture.for_resources(
        [MyApp.User, MyApp.Post],
        title: "User Management Architecture"
      )

  """
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
    data_layer_apps = get_data_layer_applications(resources)

    all_apps = Enum.uniq(get_application_names(resources) ++ data_layer_apps)

    otp_app_boundaries = build_all_otp_application_boundaries(all_apps, resources, entity_names)

    %Boundary{
      type: :system_boundary,
      alias: "beam",
      label: "BEAM",
      entries: otp_app_boundaries
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
        build_app_entries(resources, otp_app) ++
          build_domain_boundaries(app_resources, entity_names)

      %Boundary{
        type: :system_boundary,
        alias: to_string(otp_app),
        label: "#{otp_app} Application",
        entries: entries
      }
    end)
  end

  @spec build_app_entries(resources :: [Ash.Resource.t()], otp_app :: Application.app()) :: [
          Element.t()
        ]
  defp build_app_entries(resources, otp_app) do
    resources
    |> Enum.map(&Ash.Resource.Info.data_layer/1)
    |> Enum.uniq()
    |> Enum.filter(&(Application.get_application(&1) == otp_app))
    |> Enum.map(fn data_layer ->
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
