defmodule AshDiagram.Class do
  @moduledoc """
  Provides functions to handle Mermaid
  [Class Diagrams](https://mermaid.js.org/syntax/classDiagram.html).
  """

  @behaviour AshDiagram

  alias AshDiagram.Class.Class
  alias AshDiagram.Class.Relationship

  @directions %{
    top_bottom: "TB",
    bottom_top: "BT",
    left_right: "LR",
    right_left: "RL"
  }
  @direction_labels Map.keys(@directions)
  direction_typespec = Enum.reduce(@direction_labels, &{:|, [], [&1, &2]})
  @type direction() :: unquote(direction_typespec)

  @type config() :: map()

  @type t() :: %__MODULE__{
          title: String.t() | nil,
          config: config() | nil,
          direction: direction() | nil,
          # TODO: Do Namespace, Interaction, Note, Style, ClassDef, CssClass
          entries: [Class.t() | Relationship.t()]
        }
  @enforce_keys [:entries]
  defstruct [:entries, title: nil, config: nil, direction: nil]

  @doc false
  @impl AshDiagram
  def compose(%__MODULE__{} = diagram) do
    [
      compose_header(diagram),
      "classDiagram\n",
      if diagram.direction do
        ["  direction ", Map.fetch!(@directions, diagram.direction), "\n"]
      else
        []
      end,
      Enum.map(diagram.entries, fn %mod{} = entry -> mod.compose(entry) end)
    ]
  end

  @spec compose_header(diagram :: t()) :: iodata()
  defp compose_header(diagram)
  defp compose_header(%__MODULE__{title: nil, config: nil}), do: []

  defp compose_header(%__MODULE__{title: title, config: config}) do
    [
      "---\n",
      if title do
        ["title: ", title |> IO.iodata_to_binary() |> inspect(), "\n"]
      else
        []
      end,
      if config do
        ["config: ", JSON.encode!(config), "\n"]
      else
        []
      end,
      "---\n"
    ]
  end
end
