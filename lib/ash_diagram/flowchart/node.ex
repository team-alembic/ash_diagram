defmodule AshDiagram.Flowchart.Node do
  @moduledoc """
  Represents a node in a flowchart with various shapes and labels.
  """

  @shapes %{
    rectangle: {"[", "]"},
    rounded: {"(", ")"},
    stadium: {"([", "])"},
    circle: {"((", "))"},
    rhombus: {"{", "}"},
    hexagon: {"{{", "}}"},
    parallelogram: {"[/", "/]"},
    parallelogram_alt: {"[\\", "\\]"},
    trapezoid: {"[/", "\\]"},
    trapezoid_alt: {"[\\", "/]"},
    database: {"[(", ")]"},
    cylindrical: {"[[", "]]"},
    subroutine: {"[[", "]]"},
    flag: {">", "]"},
    lean_right: {">/", "/]"},
    lean_left: {"[\\", "\\]"}
  }
  @shape_labels Map.keys(@shapes)
  shape_typespec = Enum.reduce(@shape_labels, &{:|, [], [&1, &2]})
  @type shape() :: unquote(shape_typespec)

  @type t() :: %__MODULE__{
          id: iodata(),
          label: iodata() | nil,
          shape: shape() | nil
        }

  @enforce_keys [:id]
  defstruct [:id, :label, :shape]

  @doc """
  Composes the Mermaid syntax for a node.
  """
  @spec compose(t()) :: iodata()
  def compose(%__MODULE__{id: id, label: label, shape: shape}) do
    [
      "  ",
      id,
      if label do
        compose_shape(shape || :rectangle, label)
      else
        ""
      end,
      "\n"
    ]
  end

  @spec compose_shape(shape(), iodata()) :: iodata()
  defp compose_shape(shape, label) do
    {opening, closing} = Map.fetch!(@shapes, shape)
    [opening, label, closing]
  end
end
