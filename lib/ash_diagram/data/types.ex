defmodule AshDiagram.Data.Types do
  @moduledoc false

  alias Ash.Resource.Attribute
  alias Ash.Resource.Info

  @typedoc """
  An owner module embedding a target module once (`:one`) or as a list (`:many`).
  """
  @type composition() :: {owner :: module(), target :: module(), cardinality :: :one | :many}

  @doc """
  Finds every embedded resource reachable through the attribute types of the
  given modules, recursively. Embedded resources have no domain, so they are
  never listed by `Ash.Domain.Info.resources/1`.
  """
  @spec compositions(
          modules :: [module()],
          attribute_fun :: (module() -> [Attribute.t()])
        ) :: [composition()]
  def compositions(modules, attribute_fun),
    do: collect(modules, attribute_fun, MapSet.new(modules))

  @spec collect(
          modules :: [module()],
          attribute_fun :: (module() -> [Attribute.t()]),
          seen :: MapSet.t(module())
        ) :: [composition()]
  defp collect([], _attribute_fun, _seen), do: []

  defp collect([module | rest], attribute_fun, seen) do
    compositions =
      module
      |> attribute_fun.()
      |> Enum.flat_map(&composition(module, &1.type))

    new_targets =
      compositions
      |> Enum.map(&elem(&1, 1))
      |> Enum.reject(&MapSet.member?(seen, &1))
      |> Enum.uniq()

    compositions ++
      collect(rest ++ new_targets, attribute_fun, MapSet.union(seen, MapSet.new(new_targets)))
  end

  @spec composition(owner :: module(), type :: Ash.Type.t()) :: [composition()]
  defp composition(owner, {:array, type}) do
    for {^owner, target, _cardinality} <- composition(owner, type), do: {owner, target, :many}
  end

  defp composition(owner, type) do
    if Info.resource?(type) and Info.embedded?(type),
      do: [{owner, type, :one}],
      else: []
  end
end
