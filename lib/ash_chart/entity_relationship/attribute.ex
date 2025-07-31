defmodule AshChart.EntityRelationship.Attribute do
  @moduledoc """
  Represents an attribute of an entity in the Entity Relationship Diagram (ERD).
  """

  @type t() :: %__MODULE__{
          type: iodata(),
          name: iodata(),
          comment: iodata() | nil,
          is_primary_key?: boolean(),
          is_foreign_key?: boolean(),
          is_unique_key?: boolean()
        }

  @enforce_keys [:name, :type]
  defstruct [
    :name,
    :type,
    comment: nil,
    is_primary_key?: false,
    is_foreign_key?: false,
    is_unique_key?: false
  ]

  @doc false
  @spec compose(attribute :: t()) :: iodata()
  def compose(%__MODULE__{} = attribute) do
    [
      "    ",
      attribute.type,
      " ",
      attribute.name,
      compose_key_type(attribute),
      if attribute.comment do
        [
          " ",
          attribute.comment |> IO.iodata_to_binary() |> inspect()
        ]
      else
        []
      end,
      "\n"
    ]
  end

  @spec compose_key_type(attribute :: t()) :: iodata()
  defp compose_key_type(attribute)

  defp compose_key_type(%__MODULE__{
         is_primary_key?: false,
         is_foreign_key?: false,
         is_unique_key?: false
       }),
       do: []

  defp compose_key_type(%__MODULE__{} = attribute) do
    [
      " ",
      [
        if attribute.is_primary_key? do
          "PK"
        end,
        if attribute.is_foreign_key? do
          "FK"
        end,
        if attribute.is_unique_key? do
          "UK"
        end
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.intersperse(","),
      " "
    ]
  end
end
