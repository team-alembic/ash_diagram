defmodule AshDiagram.Flowchart do
  @moduledoc """
  Provides functions to handle Mermaid
  [Flowcharts](https://mermaid.js.org/syntax/flowchart.html).
  """

  @behaviour AshDiagram

  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style
  alias AshDiagram.Flowchart.Subgraph

  @directions %{
    top_bottom: "TD",
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
          entries: [Node.t() | Edge.t() | Subgraph.t() | Style.t()]
        }
  @enforce_keys [:entries]
  defstruct [:entries, title: nil, config: nil, direction: nil]

  @doc false
  @impl AshDiagram
  def compose(%__MODULE__{} = diagram) do
    [
      compose_header(diagram),
      "flowchart ",
      if diagram.direction do
        Map.fetch!(@directions, diagram.direction)
      else
        "TD"
      end,
      "\n",
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
        ["config: ", Jason.encode!(config), "\n"]
      else
        []
      end,
      "---\n"
    ]
  end
end
