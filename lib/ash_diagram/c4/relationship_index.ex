defmodule AshDiagram.C4.RelationshipIndex do
  @moduledoc """
  Represents a relationship index in a C4 diagram.
  """

  alias AshDiagram.C4

  @type t() :: %__MODULE__{
          index: non_neg_integer(),
          from: iodata(),
          to: iodata(),
          label: iodata() | nil,
          tags: C4.tags() | nil,
          link: iodata() | nil
        }

  @enforce_keys [:index, :from, :to]
  defstruct [:index, :from, :to, label: nil, tags: nil, link: nil]

  @doc false
  @spec compose(relation :: t(), indent :: iodata()) :: iodata()
  def compose(%__MODULE__{} = relation, indent) do
    [
      indent,
      "RelIndex",
      C4.compose_attributes([
        {:index, relation.index},
        {:string, relation.from},
        {:string, relation.to},
        {:string, relation.label},
        {:map, relation.tags},
        {:string, relation.link}
      ]),
      "\n"
    ]
  end
end
