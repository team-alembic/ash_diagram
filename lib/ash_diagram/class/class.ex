defmodule AshDiagram.Class.Class do
  @moduledoc """
  Represents a class in the Class Diagram.
  """

  alias AshDiagram.Class.Member

  @type t() :: %__MODULE__{
          id: iodata(),
          generic: iodata() | nil,
          label: iodata() | nil,
          members: [member()]
        }

  @type member() :: Member.t()

  @enforce_keys [:id]
  defstruct [:id, :generic, :label, members: []]

  @doc false
  @spec compose(entity :: t()) :: iodata()
  def compose(%__MODULE__{id: id} = class) do
    [
      "  class `",
      id,
      "`",
      case class.label do
        nil ->
          []

        label ->
          [
            "[",
            label |> IO.iodata_to_binary() |> inspect(),
            "]"
          ]
      end,
      case class.generic do
        nil -> []
        generic -> [?~, generic, ?~]
      end,
      case class.members do
        [] ->
          "\n"

        members ->
          [
            " {\n",
            compose_members(members),
            "  }\n"
          ]
      end
    ]
  end

  @spec compose_members(members :: [member(), ...]) :: iodata()
  defp compose_members(members) do
    Enum.map(members, &[Member.compose(&1, "    "), "\n"])
  end
end
