defmodule AshDiagram.Data.Types do
  @moduledoc false

  alias Ash.Resource.Attribute
  alias Ash.Resource.Info
  alias Ash.TypedStruct.Field

  @typedoc """
  An owner module embedding a target module in a field, once (`:one`), once or
  `nil` (`:optional`) or as a list (`:many`).
  """
  @type composition() ::
          {owner :: module(), field :: atom(), target :: module(),
           cardinality :: :one | :optional | :many}

  @doc """
  Finds every embedded resource and typed struct reachable through the
  attribute types of the given modules, recursively. Neither has a domain, so
  they are never listed by `Ash.Domain.Info.resources/1`.
  """
  @spec compositions(
          modules :: [module()],
          attribute_fun :: (module() -> [Attribute.t()])
        ) :: [composition()]
  def compositions(modules, attribute_fun),
    do: collect(modules, attribute_fun, MapSet.new(modules))

  @typedoc """
  A resource using a target module in an action, as an argument or as the
  return type of a generic action.
  """
  @type dependency() :: {resource :: module(), action :: atom(), target :: module()}

  @doc """
  Finds every embedded resource and typed struct used by the actions of the
  given resources. Like the method signature, private arguments count, too.
  """
  @spec dependencies(modules :: [module()]) :: [dependency()]
  def dependencies(modules) do
    for resource <- modules,
        Info.resource?(resource),
        action <- Info.actions(resource),
        %{type: type, constraints: constraints} <- action_types(action),
        {target, _cardinality} <- target(type, constraints),
        uniq: true,
        do: {resource, action.name, target}
  end

  @doc """
  Returns `true` if the module is an `Ash.TypedStruct`.
  """
  @spec typed_struct?(module :: module()) :: boolean()
  def typed_struct?(module), do: Spark.Dsl.is?(module, Ash.TypedStruct)

  @spec collect(
          modules :: [module()],
          attribute_fun :: (module() -> [Attribute.t()]),
          seen :: MapSet.t(module())
        ) :: [composition()]
  defp collect([], _attribute_fun, _seen), do: []

  defp collect([module | rest], attribute_fun, seen) do
    compositions =
      module
      |> fields(attribute_fun)
      |> Enum.flat_map(fn field ->
        for {target, cardinality} <- target(field.type, field.constraints),
            do: {module, field.name, target, cardinality(cardinality, field.allow_nil?)}
      end)

    new_targets =
      compositions
      |> Enum.map(&elem(&1, 2))
      |> Enum.reject(&MapSet.member?(seen, &1))
      |> Enum.uniq()

    compositions ++
      collect(rest ++ new_targets, attribute_fun, MapSet.union(seen, MapSet.new(new_targets)))
  end

  @spec fields(
          module :: module(),
          attribute_fun :: (module() -> [Attribute.t()])
        ) :: [Attribute.t() | Field.t()]
  defp fields(module, attribute_fun) do
    if typed_struct?(module),
      do: Ash.TypedStruct.Info.fields(module),
      else: attribute_fun.(module)
  end

  # A list may be empty anyway, only a single value becomes optional
  @spec cardinality(cardinality :: :one | :many, allow_nil? :: boolean()) ::
          :one | :optional | :many
  defp cardinality(:one, true), do: :optional
  defp cardinality(cardinality, _allow_nil?), do: cardinality

  @spec action_types(action :: Ash.Resource.Actions.action()) ::
          [%{type: Ash.Type.t(), constraints: Keyword.t()}]
  defp action_types(%{type: :action, returns: returns, constraints: constraints} = action)
       when not is_nil(returns),
       do: [%{type: returns, constraints: constraints || []} | action.arguments]

  defp action_types(action), do: action.arguments

  # The embedded resource or typed struct behind a type, if any
  @spec target(type :: Ash.Type.t(), constraints :: Keyword.t()) ::
          [{module(), :one | :many}]
  defp target({:array, type}, constraints) do
    for {target, _cardinality} <- target(type, Keyword.get(constraints, :items, [])),
        do: {target, :many}
  end

  defp target(Ash.Type.Struct, constraints) do
    case Keyword.fetch(constraints, :instance_of) do
      {:ok, module} -> target(module, [])
      :error -> []
    end
  end

  defp target(type, _constraints) do
    if (Info.resource?(type) and Info.embedded?(type)) or typed_struct?(type),
      do: [{type, :one}],
      else: []
  end
end
