defmodule AshDiagram.C4.Boundary do
  @moduledoc """
  Represents a boundary in a C4 diagram.
  """

  alias AshDiagram.C4

  @types %{
    boundary: "Boundary",
    system_boundary: "System_Boundary",
    container_boundary: "Container_Boundary",
    component_boundary: "Component_Boundary"
  }
  @type_keys Map.keys(@types)
  typespec = Enum.reduce(@type_keys, &{:|, [], [&1, &2]})
  @type type() :: unquote(typespec)

  @type t() :: %__MODULE__{
          type: type(),
          alias: iodata(),
          label: iodata(),
          tags: C4.tags() | nil,
          link: iodata() | nil,
          entries: nonempty_list(C4.entry())
        }

  @enforce_keys [:type, :alias, :label, :entries]
  defstruct [:type, :alias, :label, :entries, tags: nil, link: nil]

  @doc false
  @spec compose(boundary :: t(), indent :: iodata()) :: iodata()
  def compose(%__MODULE__{} = boundary, indent) do
    [
      indent,
      Map.fetch!(@types, boundary.type),
      C4.compose_attributes([
        {:string, boundary.alias},
        {:string, boundary.label},
        {:map, boundary.tags},
        {:string, boundary.link}
      ]),
      " {\n",
      Enum.map(boundary.entries, &C4.compose_entry(&1, [indent, "  "])),
      indent,
      "}\n"
    ]
  end
end
