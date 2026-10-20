defmodule AshDiagram.Data.Class do
  @moduledoc """
  Provides functions to create UML Class Diagrams for Ash applications.

  This module generates class diagrams showing Ash resources with their attributes,
  calculations, aggregates, actions, and relationships. Public and private visibility
  is respected based on the Ash resource configuration.

  ## Ash-Specific Features

  - **Resource Attributes**: All resource attributes with Ash types
  - **Calculations**: Ash calculations as computed fields
  - **Aggregates**: Ash aggregates with their types
  - **Actions**: Resource actions (create, read, update, delete, action) as methods
  - **Relationships**: Ash relationships with proper cardinality mapping
  - **Embedded Resources**: Embedded resources used as attribute types, shown as compositions
  - **Typed Structs**: `Ash.TypedStruct` modules used as attribute types, shown as compositions;
    `:struct` types are named after their `instance_of` constraint
  - **Visibility**: Respects Ash `public?` settings for attributes and relationships
  - **Extensions**: Automatically includes diagrams from Ash extensions

  """

  alias Ash.Domain.Info
  alias Ash.Resource.Aggregate
  alias Ash.Resource.Attribute
  alias Ash.Resource.Calculation
  alias Ash.Resource.Relationships
  alias AshDiagram.Class, as: DiagramImpl
  alias AshDiagram.Class.Relationship.Pointer
  alias AshDiagram.Data.Extension
  alias AshDiagram.Data.Types

  @typedoc """
  Configuration option for class diagram generation.

  Available options:
  - `{:name, :full | :short}` - How to display resource names. `:full` shows complete module names, `:short` shows shortened names with common prefixes removed
  - `{:show_private?, boolean()}` - Whether to include private attributes, calculations, aggregates, and relationships in the diagram
  - `{:labels, [:compositions | :dependencies]}` - Which edges are labeled. `:compositions` labels the edge to an embedded resource or typed struct with the field holding it, `:dependencies` labels the edge to an embedded resource or typed struct used by actions with the action names
  """
  @type option() ::
          {:name, :full | :short}
          | {:show_private?, boolean()}
          | {:labels, [:compositions | :dependencies]}

  @typedoc """
  List of configuration options for class diagram generation.
  """
  @type options() :: [option()]

  @default_options [
    name: :short,
    show_private?: false,
    labels: [:compositions, :dependencies]
  ]

  @doc """
  Generates a class diagram for the given OTP applications.

  Creates a UML class diagram showing all Ash resources from the specified
  OTP applications, including their attributes, calculations, aggregates,
  actions, and relationships.

  ## Parameters

  - `applications` - List of OTP application names (e.g., `[:my_app, :other_app]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate class diagram for a single application
      AshDiagram.Data.Class.for_applications([:my_app])

      # Generate diagram with full module names
      AshDiagram.Data.Class.for_applications([:my_app], name: :full)

      # Include private attributes and relationships
      AshDiagram.Data.Class.for_applications([:my_app], show_private?: true)

  """
  @spec for_applications(applications :: [Application.app()], options :: options()) ::
          AshDiagram.t()
  def for_applications(applications, options \\ []),
    do: applications |> Enum.flat_map(&Ash.Info.domains/1) |> for_domains(options)

  @doc """
  Generates a class diagram for the given Ash domains.

  Creates a UML class diagram showing all resources within the specified domains,
  including their attributes, calculations, aggregates, actions, and relationships.

  ## Parameters

  - `domains` - List of Ash domain modules (e.g., `[MyApp.Blog, MyApp.Accounts]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate class diagram for specific domains
      AshDiagram.Data.Class.for_domains([MyApp.Blog, MyApp.Accounts])

      # Generate diagram with short names only
      AshDiagram.Data.Class.for_domains([MyApp.Blog], name: :short)

  """
  @spec for_domains(domains :: [Ash.Domain.t()], options :: options()) :: AshDiagram.t()
  def for_domains(domains, options \\ []),
    do: domains |> Enum.flat_map(&Info.resources/1) |> for_resources(options)

  @doc """
  Generates a class diagram for the given Ash resources.

  Creates a UML class diagram showing the specified resources with:
  - Class boxes containing attributes, calculations, aggregates, and actions
  - Relationship lines with cardinality indicators
  - Public/private visibility indicators
  - Type information for all fields and methods

  ## Parameters

  - `resources` - List of Ash resource modules (e.g., `[MyApp.User, MyApp.Post]`)
  - `options` - Keyword list of options, see `t:option/0` for available options

  ## Examples

      # Generate class diagram for specific resources
      AshDiagram.Data.Class.for_resources([MyApp.User, MyApp.Post])

      # Use full module names and show private fields
      AshDiagram.Data.Class.for_resources(
        [MyApp.User, MyApp.Post],
        name: :full,
        show_private?: true
      )

      # Generate diagram with only public elements
      AshDiagram.Data.Class.for_resources([MyApp.User], show_private?: false)

  """
  @spec for_resources(resources :: [Ash.Resource.t()], options :: options()) :: AshDiagram.t()
  def for_resources(resources, options \\ []) do
    options = Keyword.merge(@default_options, options)

    {attribute_fun, _calculation_fun, _aggregate_fun, _relationship_fun} =
      access_functions = build_access_functions(options[:show_private?])

    # shortcut: only actions of the given resources count, not of embedded resources found
    # through attributes; upgrade when embedded resources with custom actions show up
    dependencies = Types.dependencies(resources)
    dependency_targets = Enum.map(dependencies, &elem(&1, 2))
    seeds = Enum.uniq(resources ++ dependency_targets)
    compositions = Types.compositions(seeds, attribute_fun)
    modules = Enum.uniq(seeds ++ Enum.map(compositions, &elem(&1, 2)))

    {typed_structs, resources} = Enum.split_with(modules, &Types.typed_struct?/1)
    entity_names = build_entity_names(modules, options[:name])

    entries =
      build_class_entries(resources, entity_names, access_functions) ++
        build_typed_struct_entries(typed_structs, entity_names)

    relationships =
      build_relationships(resources, access_functions) ++
        build_compositions(compositions, :compositions in options[:labels]) ++
        build_dependencies(dependencies, compositions, :dependencies in options[:labels])

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
      aggregates = build_aggregates(resource, aggregate_fun.(resource))
      actions = build_actions(resource, entity_names[resource])

      %DiagramImpl.Class{
        id: inspect(resource),
        label: entity_names[resource],
        members: attributes ++ calculations ++ aggregates ++ actions
      }
    end
  end

  @spec build_typed_struct_entries(
          typed_structs :: [module()],
          entity_names :: %{module() => iodata()}
        ) :: [DiagramImpl.Class.t()]
  defp build_typed_struct_entries(typed_structs, entity_names) do
    for typed_struct <- Enum.sort(typed_structs) do
      %DiagramImpl.Class{
        id: inspect(typed_struct),
        label: entity_names[typed_struct],
        members:
          for %{name: name, type: type, constraints: constraints, allow_nil?: allow_nil?} <-
                Ash.TypedStruct.Info.fields(typed_struct) do
            %DiagramImpl.Field{
              type: compose_type(type, constraints, allow_nil?),
              visibility: :public,
              name: Atom.to_string(name)
            }
          end
      }
    end
  end

  @spec build_attributes(attributes :: [Attribute.t()]) :: [DiagramImpl.Field.t()]
  defp build_attributes(attributes) do
    for %Attribute{
          type: type,
          constraints: constraints,
          name: name,
          allow_nil?: allow_nil?,
          public?: public?
        } <- attributes do
      %DiagramImpl.Field{
        type: compose_type(type, constraints, allow_nil?),
        visibility: if(public?, do: :public, else: :private),
        name: Atom.to_string(name)
      }
    end
  end

  @spec build_calculations(calculations :: [Calculation.t()]) :: [DiagramImpl.Field.t()]
  defp build_calculations(calculations) do
    for %Calculation{name: name, type: type, constraints: constraints, public?: public?} <-
          calculations do
      %DiagramImpl.Field{
        type: compose_type(type, constraints),
        visibility: if(public?, do: :public, else: :private),
        name: Atom.to_string(name)
      }
    end
  end

  @spec build_aggregates(resource :: Ash.Resource.t(), aggregates :: [Aggregate.t()]) ::
          [DiagramImpl.Field.t()]
  defp build_aggregates(resource, aggregates) do
    for %Aggregate{name: name, public?: public?} = aggregate <- aggregates do
      %DiagramImpl.Field{
        type: compose_type(aggregate_type(resource, aggregate)),
        visibility: if(public?, do: :public, else: :private),
        name: Atom.to_string(name)
      }
    end
  end

  @spec aggregate_type(resource :: Ash.Resource.t(), aggregate :: Aggregate.t()) ::
          Ash.Type.t() | nil
  defp aggregate_type(resource, aggregate) do
    case Ash.Resource.Info.aggregate_type(resource, aggregate) do
      {:ok, type} -> type
      # Custom aggregates can't be resolved by kind, they declare their type explicitly
      {:error, _reason} -> Ash.Type.get_type(aggregate.type)
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

  # TODO: label relationships, too. A relationship and its reverse (belongs_to and
  # has_many) are merged into one edge, which has room for one label only.
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

  @spec build_compositions(compositions :: [Types.composition()], label? :: boolean()) ::
          [DiagramImpl.Relationship.t()]
  defp build_compositions(compositions, label?) do
    compositions
    |> Enum.sort()
    |> Enum.map(fn {owner, field, target, cardinality} ->
      %DiagramImpl.Relationship{
        left: %Pointer{class: inspect(owner), cardinality: "1", type: :composition},
        right: %Pointer{
          class: inspect(target),
          cardinality: composition_cardinality(cardinality)
        },
        style: :solid,
        label: if(label?, do: Atom.to_string(field))
      }
    end)
    |> Enum.uniq()
  end

  # One edge per resource and target, left out where a composition already connects both
  @spec build_dependencies(
          dependencies :: [Types.dependency()],
          compositions :: [Types.composition()],
          label? :: boolean()
        ) :: [DiagramImpl.Relationship.t()]
  defp build_dependencies(dependencies, compositions, label?) do
    composed =
      MapSet.new(compositions, fn {owner, _field, target, _cardinality} -> {owner, target} end)

    dependencies
    |> Enum.reject(fn {resource, _action, target} -> {resource, target} in composed end)
    |> Enum.group_by(fn {resource, _action, target} -> {resource, target} end, &elem(&1, 1))
    |> Enum.sort()
    |> Enum.map(fn {{resource, target}, actions} ->
      %DiagramImpl.Relationship{
        left: %Pointer{class: inspect(resource)},
        right: %Pointer{class: inspect(target), type: :dependency},
        style: :dashed,
        label: if(label?, do: actions |> Enum.sort() |> Enum.join(", "))
      }
    end)
  end

  @spec collect_extensions(resources :: [Ash.Resource.t()]) :: [module()]
  defp collect_extensions(resources) do
    resource_extensions = Enum.flat_map(resources, &Ash.Resource.Info.extensions/1)

    domain_extensions =
      resources
      |> Enum.map(&Ash.Resource.Info.domain/1)
      # Embedded resources have no domain
      |> Enum.reject(&is_nil/1)
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
           :action -> compose_type(action.returns, action.constraints, action.allow_nil?)
           _action -> self_name
         end},
      arguments:
        Enum.map(
          action.arguments,
          &{Atom.to_string(&1.name), compose_type(&1.type, &1.constraints, &1.allow_nil?)}
        )
    }
  end

  @spec compose_type(
          type :: Ash.Type.t(),
          constraints :: Keyword.t(),
          allow_nil? :: boolean()
        ) :: iodata()
  defp compose_type(type, constraints \\ [], allow_nil? \\ false)
  defp compose_type(type, constraints, true), do: [??, compose_type(type, constraints)]

  defp compose_type({:array, inner_type}, constraints, false),
    do: [compose_type(inner_type, Keyword.get(constraints, :items, [])), "[]"]

  defp compose_type(nil, _constraints, false), do: "unknown"

  defp compose_type(Ash.Type.Struct, constraints, false) do
    case Keyword.fetch(constraints, :instance_of) do
      {:ok, module} -> compose_type(module)
      :error -> "Struct"
    end
  end

  defp compose_type(module, _constraints, false), do: module |> Module.split() |> List.last()

  @spec cardinality(relationship :: Relationships.relationship()) :: {iodata(), iodata()}
  defp cardinality(%Relationships.BelongsTo{allow_nil?: true}), do: {"0..1", "*"}
  defp cardinality(%Relationships.BelongsTo{}), do: {"1", "*"}
  defp cardinality(%Relationships.HasMany{}), do: {"*", "0..1"}
  defp cardinality(%Relationships.HasOne{}), do: {"1", "0..1"}
  defp cardinality(%Relationships.ManyToMany{}), do: {"*", "*"}

  @spec composition_cardinality(cardinality :: :one | :optional | :many) :: iodata()
  defp composition_cardinality(:one), do: "1"
  defp composition_cardinality(:optional), do: "0..1"
  defp composition_cardinality(:many), do: "*"

  @spec pointer_type(relationship :: Relationships.relationship()) ::
          {Pointer.type(), Pointer.type()}
  defp pointer_type(%Relationships.BelongsTo{}), do: {:composition, :aggregation}
  defp pointer_type(%Relationships.HasMany{}), do: {:aggregation, :composition}
  defp pointer_type(%Relationships.HasOne{}), do: {:aggregation, :composition}
  defp pointer_type(%Relationships.ManyToMany{}), do: {:association, :association}

  @spec common_prefix(modules :: [module()]) :: [String.t()]
  defp common_prefix(modules)
  defp common_prefix([]), do: []

  defp common_prefix([module]) do
    parts = Module.split(module)
    Enum.take(parts, length(parts) - 1)
  end

  defp common_prefix(modules) do
    modules
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
