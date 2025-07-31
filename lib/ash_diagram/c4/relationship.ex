defmodule AshDiagram.C4.Relationship do
  @moduledoc """
  Represents a relationship in a C4 diagram.
  """

  alias AshDiagram.C4

  @types %{
    rel: "Rel",
    bi_rel: "BiRel",
    rel_u: "Rel_Up",
    rel_d: "Rel_Down",
    rel_l: "Rel_Left",
    rel_r: "Rel_Right",
    rel_back: "Rel_Back"
  }
  @type_keys Map.keys(@types)
  typespec = Enum.reduce(@type_keys, &{:|, [], [&1, &2]})
  @type type() :: unquote(typespec)

  @type t() :: %__MODULE__{
          type: type(),
          from: iodata(),
          to: iodata(),
          label: iodata(),
          technology: iodata() | nil,
          description: iodata() | nil,
          sprite: iodata() | nil,
          tags: C4.tags() | nil,
          link: iodata() | nil
        }

  @enforce_keys [:type, :from, :to, :label]
  defstruct [
    :type,
    :from,
    :to,
    :label,
    technology: nil,
    description: nil,
    sprite: nil,
    tags: nil,
    link: nil
  ]

  @doc false
  @spec compose(relation :: t(), indent :: iodata()) :: iodata()
  def compose(%__MODULE__{} = relation, indent) do
    [
      indent,
      Map.fetch!(@types, relation.type),
      C4.compose_attributes([
        {:string, relation.from},
        {:string, relation.to},
        {:string, relation.label},
        {:string, relation.technology},
        {:string, relation.description},
        {:string, relation.sprite},
        {:map, relation.tags},
        {:string, relation.link}
      ]),
      "\n"
    ]
  end
end
