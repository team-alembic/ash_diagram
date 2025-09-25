defmodule AshDiagram.Class.Relationship do
  @moduledoc """
  Represents a relationship between two classes in the Class Diagram.
  """

  alias AshDiagram.Class.Relationship.Pointer

  @type style() :: :solid | :dashed

  @type t() :: %__MODULE__{
          left: Pointer.t(),
          right: Pointer.t(),
          style: style(),
          label: iodata() | nil
        }

  @enforce_keys [:left, :right, :style]
  defstruct [:left, :right, :style, label: nil]

  @doc false
  @spec compose(entity :: t()) :: iodata()
  def compose(%__MODULE__{} = relationship) do
    [
      "  ",
      Pointer.compose(relationship.left, :left),
      case relationship.style do
        :solid -> "--"
        :dashed -> ".."
      end,
      Pointer.compose(relationship.right, :right),
      if relationship.label do
        [" : ", relationship.label]
      else
        []
      end,
      "\n"
    ]
  end
end
