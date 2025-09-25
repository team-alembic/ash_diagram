defmodule AshDiagram.Class.Relationship.Pointer do
  @moduledoc false
  @types %{
    inheritance: {"<|", "|>"},
    composition: {"*", "*"},
    aggregation: {"o", "o"},
    association: {"<", ">"},
    dependency: {"<", ">"},
    realization: {"<|", "|>"}
  }
  @type_labels Map.keys(@types)
  type_typespec = Enum.reduce(@type_labels, &{:|, [], [&1, &2]})
  @type type() :: unquote(type_typespec)

  @type t() :: %__MODULE__{
          class: iodata(),
          cardinality: iodata() | nil,
          type: type() | nil
        }

  @enforce_keys [:class]
  defstruct [:class, cardinality: nil, type: nil]

  @type side() :: :left | :right

  @doc false
  @spec compose(pointer :: t(), side :: side()) :: iodata()
  def compose(pointer, side)

  def compose(%__MODULE__{} = pointer, :left) do
    type =
      if pointer.type do
        {left, _right} = Map.fetch!(@types, pointer.type)
        left
      else
        ""
      end

    [
      "`",
      pointer.class,
      "` ",
      if pointer.cardinality do
        ["\"", pointer.cardinality, "\" "]
      else
        []
      end,
      type
    ]
  end

  def compose(%__MODULE__{} = pointer, :right) do
    type =
      if pointer.type do
        {_left, right} = Map.fetch!(@types, pointer.type)
        right
      else
        ""
      end

    [
      type,
      if pointer.cardinality do
        [" \"", pointer.cardinality, "\" "]
      else
        []
      end,
      "`",
      pointer.class,
      "`"
    ]
  end
end
