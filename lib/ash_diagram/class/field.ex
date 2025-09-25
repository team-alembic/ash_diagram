defmodule AshDiagram.Class.Field do
  @moduledoc """
  Represents a field in the Class Diagram.
  """

  alias AshDiagram.Class.Member

  @type t() :: %__MODULE__{
          visibility: Member.visibility() | nil,
          name: iodata(),
          type: Member.type() | nil,
          static: boolean()
        }

  @enforce_keys [:name]
  defstruct [:visibility, :name, :type, static: false]

  @doc false
  @spec compose(entity :: t(), indent :: iodata()) :: iodata()
  def compose(%__MODULE__{name: name} = method, indent \\ []) do
    [
      indent,
      case method.visibility do
        nil -> []
        visibility -> Member.compose_visibility(visibility)
      end,
      case method.type do
        nil -> []
        type -> Member.compose_type(type)
      end,
      " ",
      name,
      if method.static do
        "$"
      else
        []
      end
    ]
  end
end
