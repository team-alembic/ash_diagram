defmodule AshDiagram.Class.Namespace do
  @moduledoc """
  Represents a namespace grouping classes in the Class Diagram.

  The `id` must be a valid Mermaid namespace identifier (letters, digits, `_`
  and `-`). Dots create nested namespaces, so `Blog.Posts` renders as a
  `Posts` namespace inside a `Blog` namespace.
  """

  alias AshDiagram.Class.Class

  @type t() :: %__MODULE__{
          id: iodata(),
          entries: [Class.t()]
        }

  @enforce_keys [:id, :entries]
  defstruct [:id, :entries]

  @doc false
  @spec compose(namespace :: t()) :: iodata()
  def compose(%__MODULE__{id: id, entries: entries}) do
    [
      "  namespace ",
      id,
      " {\n",
      entries
      |> Enum.map(&Class.compose/1)
      |> IO.iodata_to_binary()
      |> String.split("\n", trim: true)
      |> Enum.map(&["  ", &1, "\n"]),
      "  }\n"
    ]
  end
end
