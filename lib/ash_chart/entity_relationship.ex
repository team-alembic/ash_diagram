defmodule AshChart.EntityRelationship do
  @moduledoc """
  Provides functions to handle Mermaid
  [Entity Relationship Diagrams](https://mermaid.js.org/syntax/entityRelationshipDiagram.html).
  """

  @behaviour AshChart

  alias AshChart.EntityRelationship.Entity
  alias AshChart.EntityRelationship.Relationship

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
          # TODO: Do Style, ClassDef and Class
          entries: [Entity.t() | Relationship.t()]
        }
  @enforce_keys [:entries]
  defstruct [:entries, title: nil, config: nil, direction: nil]

  @impl AshChart
  def compose(%__MODULE__{} = chart) do
    [
      compose_header(chart),
      "erDiagram\n",
      if chart.direction do
        ["  direction ", Map.fetch!(@directions, chart.direction), "\n"]
      else
        []
      end,
      Enum.map(chart.entries, fn %mod{} = entry -> mod.compose(entry) end)
    ]
  end

  @spec compose_header(chart :: t()) :: iodata()
  defp compose_header(chart)
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
