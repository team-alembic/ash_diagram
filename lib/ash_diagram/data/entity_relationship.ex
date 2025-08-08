defmodule AshDiagram.Data.EntityRelationship do
  @moduledoc """
  Provides functions to create Diagrams for Ash applications.
  """

  alias Ash.Domain.Info
  alias Ash.Resource.Relationships
  alias AshDiagram.Data.Extension
  alias AshDiagram.EntityRelationship, as: DiagramImpl

  @type option() :: {:name, :full | :short} | {:show_private?, boolean()}
  @type options() :: [option()]

  @default_options [
    name: :short,
    show_private?: false
  ]

  @spec for_applications(applications :: [Application.app()], options :: options()) ::
          DiagramImpl.t()
  def for_applications(applications, options \\ []),
    do: applications |> Enum.flat_map(&Ash.Info.domains/1) |> for_domains(options)

  @spec for_domains(domains :: [Ash.Domain.t()], options :: options()) :: DiagramImpl.t()
  def for_domains(domains, options \\ []),
    do: domains |> Enum.flat_map(&Info.resources/1) |> for_resources(options)

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
  defp compose_type(module, false), do: module |> Module.split() |> List.last()

  @spec cardinality(relationship :: Relationships.relationship()) ::
          {DiagramImpl.Relationship.cardinality(), DiagramImpl.Relationship.cardinality()}
  def cardinality(%Relationships.BelongsTo{allow_nil?: true}), do: {:zero_or_one, :zero_or_more}
  def cardinality(%Relationships.BelongsTo{}), do: {:exactly_one, :zero_or_more}
  def cardinality(%Relationships.HasMany{}), do: {:zero_or_more, :zero_or_one}
  def cardinality(%Relationships.HasOne{}), do: {:exactly_one, :zero_or_one}

  @spec common_prefix(parts :: [module()]) :: [String.t()]
  defp common_prefix(parts)
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
