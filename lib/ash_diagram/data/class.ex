defmodule AshDiagram.Data.Class do
  @moduledoc """
  Provides functions to create Diagrams for Ash applications.
  """

  alias Ash.Domain.Info
  alias Ash.Resource.Aggregate
  alias Ash.Resource.Attribute
  alias Ash.Resource.Calculation
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

    entries = build_class_entries(resources, entity_names, access_functions)
    relationships = build_relationships(resources, access_functions)
    extensions = collect_extensions(resources)

    Extension.construct_diagram(__MODULE__, extensions, %DiagramImpl{
      entries: entries ++ relationships
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
      shortened_name =
        resource
        |> Module.split()
        |> Enum.drop(length(common_name_parts))
        |> Enum.intersperse(".")

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

  @spec build_class_entries(
          resources :: [Ash.Resource.t()],
          entity_names :: %{Ash.Resource.t() => iodata()},
          access_functions :: {function(), function(), function(), function()}
        ) :: [DiagramImpl.Class.t()]
  defp build_class_entries(
         resources,
         entity_names,
         {attribute_fun, calculation_fun, aggregate_fun, _relationship_fun}
       ) do
    for resource <- Enum.sort(resources) do
      attributes = build_attributes(attribute_fun.(resource))
      calculations = build_calculations(calculation_fun.(resource))
      aggregates = build_aggregates(aggregate_fun.(resource))
      actions = build_actions(resource, entity_names[resource])

      %DiagramImpl.Class{
        id: inspect(resource),
        label: entity_names[resource],
        members: attributes ++ calculations ++ aggregates ++ actions
      }
    end
  end

  @spec build_attributes(attributes :: [Attribute.t()]) :: [DiagramImpl.Field.t()]
  defp build_attributes(attributes) do
    for %Attribute{type: type, name: name, allow_nil?: allow_nil?, public?: public?} <- attributes do
      %DiagramImpl.Field{
        type: compose_type(type, allow_nil?),
        visibility: if(public?, do: :public, else: :private),
        name: Atom.to_string(name)
      }
    end
  end

  @spec build_calculations(calculations :: [Calculation.t()]) :: [DiagramImpl.Field.t()]
  defp build_calculations(calculations) do
    for %Calculation{name: name, type: type, public?: public?} <- calculations do
      %DiagramImpl.Field{
        type: compose_type(type),
        visibility: if(public?, do: :public, else: :private),
        name: Atom.to_string(name)
      }
    end
  end

  @spec build_aggregates(aggregates :: [Aggregate.t()]) :: [DiagramImpl.Field.t()]
  defp build_aggregates(aggregates) do
    for %Aggregate{name: name, type: type, public?: public?} <- aggregates do
      %DiagramImpl.Field{
        type: compose_type(type),
        visibility: if(public?, do: :public, else: :private),
        name: Atom.to_string(name)
      }
    end
  end

  @spec build_actions(resource :: Ash.Resource.t(), entity_name :: iodata()) :: [
          DiagramImpl.Method.t()
        ]
  defp build_actions(resource, entity_name) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.map(&compose_action(&1, entity_name))
  end

  @spec build_relationships(
          resources :: [Ash.Resource.t()],
          access_functions :: {function(), function(), function(), function()}
        ) :: [DiagramImpl.Relationship.t()]
  defp build_relationships(
         resources,
         {_attribute_fun, _calculation_fun, _aggregate_fun, relationship_fun}
       ) do
    resources
    |> Enum.flat_map(relationship_fun)
    |> Enum.sort()
    |> Enum.map(&build_relationship/1)
    |> Enum.map(&normalize_relationship/1)
    |> Enum.uniq()
  end

  @spec build_relationship(relationship :: Relationships.relationship()) ::
          DiagramImpl.Relationship.t()
  defp build_relationship(
         %{source: source, destination: destination, public?: public?} = relationship
       ) do
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

  @spec compose_action(action :: Ash.Resource.Actions.action(), self_name :: iodata()) ::
          DiagramImpl.Method.t()
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
