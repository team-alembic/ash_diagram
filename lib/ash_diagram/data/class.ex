defmodule AshDiagram.Data.Class do
  @moduledoc """
  Provides functions to create Diagrams for Ash applications.
  """

  alias Ash.Domain.Info
  alias Ash.Resource.Relationships
  alias AshDiagram.Class, as: DiagramImpl
  alias AshDiagram.Class.Relationship.Pointer
  alias AshDiagram.Data.Extension

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
          for %Ash.Resource.Attribute{
                type: type,
                name: name,
                allow_nil?: allow_nil?,
                public?: public?
              } <-
                attribute_fun.(resource) do
            %DiagramImpl.Field{
              type: compose_type(type, allow_nil?),
              visibility: if(public?, do: :public, else: :private),
              name: Atom.to_string(name)
            }
          end

        calculations =
          for %Ash.Resource.Calculation{name: name, type: type, public?: public?} <-
                calculation_fun.(resource) do
            %DiagramImpl.Field{
              type: compose_type(type),
              visibility: if(public?, do: :public, else: :private),
              name: Atom.to_string(name)
            }
          end

        aggregates =
          for %Ash.Resource.Aggregate{name: name, type: type, public?: public?} <-
                aggregate_fun.(resource) do
            %DiagramImpl.Field{
              type: compose_type(type),
              visibility: if(public?, do: :public, else: :private),
              name: Atom.to_string(name)
            }
          end

        actions =
          resource
          |> Ash.Resource.Info.actions()
          |> Enum.map(&compose_action(&1, entity_names[resource]))

        %DiagramImpl.Class{
          id: inspect(resource),
          label: entity_names[resource],
          members: attributes ++ calculations ++ aggregates ++ actions
        }
      end

    relationships =
      resources
      |> Enum.flat_map(relationship_fun)
      |> Enum.sort()
      |> Enum.map(fn %{source: source, destination: destination, public?: public?} = relationship ->
        {left_cardinality, right_cardinality} = cardinality(relationship)
        {left_type, right_type} = pointer_type(relationship)

        %DiagramImpl.Relationship{
          left: %Pointer{class: inspect(source), cardinality: left_cardinality, type: left_type},
          right: %Pointer{
            class: inspect(destination),
            cardinality: right_cardinality,
            type: right_type
          },
          style: if(public?, do: :solid, else: :dashed)
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

  @spec compose_action(action :: Ash.Resource.Actions.action(), self_name :: iodata()) ::
          DiagramImpl.Class.t()
  defp compose_action(%{name: name, type: type} = action, self_name) do
    %DiagramImpl.Method{
      name: Atom.to_string(name),
      visibility: :public,
      type:
        {:generic, Atom.to_string(type),
         case type do
           :action -> compose_type(action.returns, action.allow_nil?)
           _action -> self_name
         end},
      arguments:
        Enum.map(
          action.arguments,
          &{Atom.to_string(&1.name), compose_type(&1.type, &1.allow_nil?)}
        )
    }
  end

  @spec compose_type(type :: Ash.Type.t(), allow_nil? :: boolean()) :: iodata()
  defp compose_type(type, allow_nil? \\ false)
  defp compose_type(type, true), do: [??, compose_type(type)]

  defp compose_type({:array, inner_type}, false),
    do: {:generic, "array", compose_type(inner_type)}

  defp compose_type(module, false), do: module |> Module.split() |> List.last()

  @spec cardinality(relationship :: Relationships.relationship()) :: {iodata(), iodata()}
  defp cardinality(%Relationships.BelongsTo{allow_nil?: true}), do: {"0..1", "*"}
  defp cardinality(%Relationships.BelongsTo{}), do: {"1", "*"}
  defp cardinality(%Relationships.HasMany{}), do: {"*", "0..1"}
  defp cardinality(%Relationships.HasOne{}), do: {"1", "0..1"}
  defp cardinality(%Relationships.ManyToMany{}), do: {"*", "*"}

  @spec pointer_type(relationship :: Relationships.relationship()) ::
          {Pointer.type(), Pointer.type()}
  defp pointer_type(%Relationships.BelongsTo{}), do: {:composition, :aggregation}
  defp pointer_type(%Relationships.HasMany{}), do: {:aggregation, :composition}
  defp pointer_type(%Relationships.HasOne{}), do: {:aggregation, :composition}
  defp pointer_type(%Relationships.ManyToMany{}), do: {:association, :association}

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
           left: %Pointer{class: left_class} = left,
           right: %Pointer{class: right_class} = right
         } =
           relationship
       )
       when left_class > right_class do
    %{relationship | left: right, right: left}
  end

  defp normalize_relationship(relationship), do: relationship
end
