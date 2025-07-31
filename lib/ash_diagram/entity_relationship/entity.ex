defmodule AshDiagram.EntityRelationship.Entity do
  @moduledoc """
  Represents an entity in the Entity Relationship Diagram (ERD).
  """

  alias AshDiagram.EntityRelationship.Attribute

  @type t() :: %__MODULE__{
          id: iodata(),
          label: iodata() | nil,
          attributes: [Attribute.t()] | nil
        }

  defstruct [:id, :label, :attributes]

  @doc false
  @spec compose(entity :: t()) :: iodata()
  def compose(%__MODULE__{id: id, label: label, attributes: attributes}) do
    [
      "  ",
      id |> IO.iodata_to_binary() |> inspect(),
      if label do
        [
          "[",
          label |> IO.iodata_to_binary() |> inspect(),
          "]"
        ]
      else
        []
      end,
      if attributes do
        [
          " {\n",
          Enum.map(attributes, &Attribute.compose/1),
          "  }\n"
        ]
      else
        []
      end
    ]
  end
end
