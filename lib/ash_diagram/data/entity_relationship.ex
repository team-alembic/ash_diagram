defmodule AshDiagram.Data.EntityRelationship do
  @moduledoc """
  Provides functions to create Entity-Relationship Diagrams for Ash applications.

  This module generates ERDs showing Ash resources as entities with their attributes,
  calculations, aggregates, and relationships with proper cardinality indicators.

  ## Ash-Specific Features

  - **Resource Entities**: Ash resources displayed as ERD entities
  - **Attributes**: Resource attributes, calculations, and aggregates
  - **Relationships**: Ash relationships with cardinality derived from relationship types
  - **Visibility**: Respects Ash `public?` settings for attributes and relationships
  - **Extensions**: Automatically includes diagrams from Ash extensions

  """

  alias Ash.Domain.Info
  alias Ash.Resource.Relationships
  alias AshDiagram.Data.Extension
  alias AshDiagram.EntityRelationship, as: DiagramImpl

  @typedoc """
  Configuration option for entity-relationship diagram generation.

  Available options:
  - `{:name, :full | :short}` - How to display resource names. `:full` shows complete module names, `:short` shows shortened names with common prefixes removed
  - `{:show_private?, boolean()}` - Whether to include private attributes, calculations, aggregates, and relationships in the diagram
  """
  @type option() :: {:name, :full | :short} | {:show_private?, boolean()}

  @typedoc """
  List of configuration options for entity-relationship diagram generation.
  """
  @type options() :: [option()]

  @default_options [
    name: :short,
    show_private?: false
  ]

  @doc """
  Generates an entity-relationship diagram for the given OTP applications.

  Creates an ERD showing all Ash resources from the specified OTP applications,
  including their attributes, calculations, aggregates, and relationships
  with cardinality indicators.

  ## Parameters

  - `applications` - List of OTP application names (e.g., `[:my_app, :other_app]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate ERD for a single application
      AshDiagram.Data.EntityRelationship.for_applications([:my_app])

      # Generate diagram with full module names
      AshDiagram.Data.EntityRelationship.for_applications([:my_app], name: :full)

      # Include private attributes and relationships
      AshDiagram.Data.EntityRelationship.for_applications([:my_app], show_private?: true)

  """
  @spec for_applications(applications :: [Application.app()], options :: options()) ::
          DiagramImpl.t()
  def for_applications(applications, options \\ []),
    do: applications |> Enum.flat_map(&Ash.Info.domains/1) |> for_domains(options)

  @doc """
  Generates an entity-relationship diagram for the given Ash domains.

  Creates an ERD showing all resources within the specified domains,
  including their attributes, calculations, aggregates, and relationships
  with cardinality indicators.

  ## Parameters

  - `domains` - List of Ash domain modules (e.g., `[MyApp.Blog, MyApp.Accounts]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate ERD for specific domains
      AshDiagram.Data.EntityRelationship.for_domains([MyApp.Blog, MyApp.Accounts])

      # Generate diagram with short names only
      AshDiagram.Data.EntityRelationship.for_domains([MyApp.Blog], name: :short)

  """
  @spec for_domains(domains :: [Ash.Domain.t()], options :: options()) :: DiagramImpl.t()
  def for_domains(domains, options \\ []),
    do: domains |> Enum.flat_map(&Info.resources/1) |> for_resources(options)

  @doc """
  Generates an entity-relationship diagram for the given Ash resources.

  Creates an ERD showing the specified resources with:
  - Entity boxes containing attributes, calculations, and aggregates
  - Relationship lines with cardinality indicators (1, 0..1, *, 0..*)
  - Proper ERD notation for identifying and non-identifying relationships

  ## Parameters

  - `resources` - List of Ash resource modules (e.g., `[MyApp.User, MyApp.Post]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate ERD for specific resources
      AshDiagram.Data.EntityRelationship.for_resources([MyApp.User, MyApp.Post])

      # Use full module names and show private fields
      AshDiagram.Data.EntityRelationship.for_resources(
        [MyApp.User, MyApp.Post],
        name: :full,
        show_private?: true
      )

      # Generate diagram with only public elements
      AshDiagram.Data.EntityRelationship.for_resources([MyApp.User], show_private?: false)

  """
  @spec for_resources(resources :: [Ash.Resource.t()], options :: options()) :: DiagramImpl.t()
  def for_resources(resources, options \\ []) do
    options = Keyword.merge(@default_options, options)

    entity_names =
      case options[:name] do
        :full ->
          Map.new(resources, &{&1, inspect(&1)})

        :short ->
          common_name_parts = common_prefix(resources)

          Map.new(resources, fn resource ->
            shortened_name =
              resource
              |> Module.split()
              |> Enum.drop(length(common_name_parts))
              |> Enum.intersperse(".")

            {resource, shortened_name}
          end)
      end

    {attribute_fun, calculation_fun, aggregate_fun, relationship_fun} =
      if options[:show_private?] do
        {&Ash.Resource.Info.attributes/1, &Ash.Resource.Info.calculations/1,
         &Ash.Resource.Info.aggregates/1, &Ash.Resource.Info.relationships/1}
      else
        {&Ash.Resource.Info.public_attributes/1, &Ash.Resource.Info.public_calculations/1,
         &Ash.Resource.Info.public_aggregates/1, &Ash.Resource.Info.public_relationships/1}
      end

    entries =
      for resource <- Enum.sort(resources) do
        attributes =
          for %Ash.Resource.Attribute{type: type, name: name, allow_nil?: allow_nil?} <-
                attribute_fun.(resource) do
            %DiagramImpl.Attribute{
              type: compose_type(type, allow_nil?),
              name: Atom.to_string(name)
            }
          end

        calculations =
          for %Ash.Resource.Calculation{name: name, type: type} <- calculation_fun.(resource) do
            %DiagramImpl.Attribute{type: compose_type(type), name: Atom.to_string(name)}
          end

        aggregates =
          for %Ash.Resource.Aggregate{name: name, type: type} <- aggregate_fun.(resource) do
            %DiagramImpl.Attribute{type: compose_type(type), name: Atom.to_string(name)}
          end

        %DiagramImpl.Entity{
          id: inspect(resource),
          label: entity_names[resource],
          attributes: attributes ++ calculations ++ aggregates
        }
      end

    relationships =
      resources
      |> Enum.flat_map(relationship_fun)
      |> Enum.sort()
      |> Enum.map(fn %{source: source, destination: destination} = relationship ->
        {left_cardinality, right_cardinality} = cardinality(relationship)

        %DiagramImpl.Relationship{
          left: {inspect(source), left_cardinality},
          right: {inspect(destination), right_cardinality},
          identifying?: true,
          label: []
        }
      end)
      |> Enum.map(&normalize_relationship/1)
      |> Enum.uniq()

    resource_extensions = Enum.flat_map(resources, &Ash.Resource.Info.extensions/1)

    domain_extensions =
      resources
      |> Enum.map(&Ash.Resource.Info.domain/1)
      |> Enum.flat_map(&Info.extensions/1)

    extensions = Enum.uniq(resource_extensions ++ domain_extensions)

    Extension.construct_diagram(__MODULE__, extensions, %DiagramImpl{
      entries: entries ++ relationships
    })
  end

  @spec compose_type(type :: Ash.Type.t(), allow_nil? :: boolean()) :: iodata()
  defp compose_type(type, allow_nil? \\ false)
  defp compose_type(type, true), do: [compose_type(type), "﹖"]
  defp compose_type({:array, inner_type}, false), do: [compose_type(inner_type), "[]"]
  defp compose_type(nil, false), do: "unknown"
  defp compose_type(module, false), do: module |> Module.split() |> List.last()

  @spec cardinality(relationship :: Relationships.relationship()) ::
          {DiagramImpl.Relationship.cardinality(), DiagramImpl.Relationship.cardinality()}
  defp cardinality(%Relationships.BelongsTo{allow_nil?: true}), do: {:zero_or_one, :zero_or_more}
  defp cardinality(%Relationships.BelongsTo{}), do: {:exactly_one, :zero_or_more}
  defp cardinality(%Relationships.HasMany{}), do: {:zero_or_more, :zero_or_one}
  defp cardinality(%Relationships.HasOne{}), do: {:exactly_one, :zero_or_one}
  defp cardinality(%Relationships.ManyToMany{}), do: {:zero_or_more, :zero_or_more}

  @spec common_prefix(parts :: [module()]) :: [String.t()]
  defp common_prefix(parts)

  defp common_prefix([module]) do
    parts = Module.split(module)
    Enum.take(parts, length(parts) - 1)
  end

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

  @spec normalize_relationship(relationship :: DiagramImpl.Relationship.t()) ::
          DiagramImpl.Relationship.t()
  defp normalize_relationship(relationship)

  defp normalize_relationship(
         %DiagramImpl.Relationship{
           left: {left, left_cardinality},
           right: {right, right_cardinality}
         } = relationship
       )
       when left > right do
    %{relationship | left: {right, right_cardinality}, right: {left, left_cardinality}}
  end

  defp normalize_relationship(relationship), do: relationship
end
