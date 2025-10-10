defmodule AshDiagram.Flowchart.Subgraph do
  @moduledoc """
  Represents a subgraph in a flowchart that can contain nodes, edges, and nested subgraphs.
  """

  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node

  @directions %{
    top_bottom: "TB",
    bottom_top: "BT",
    left_right: "LR",
    right_left: "RL"
  }
  @direction_labels Map.keys(@directions)
  direction_typespec = Enum.reduce(@direction_labels, &{:|, [], [&1, &2]})
  @type direction() :: unquote(direction_typespec)

  @type t() :: %__MODULE__{
          id: iodata(),
          label: iodata() | nil,
          direction: direction() | nil,
          entries: [Node.t() | Edge.t() | t()],
          style_class: iodata() | nil
        }

  @enforce_keys [:id, :entries]
  defstruct [:id, :label, :direction, :entries, :style_class]

  @doc """
  Composes the Mermaid syntax for a subgraph.
  """
  @spec compose(t()) :: iodata()
  def compose(%__MODULE__{} = subgraph) do
    compose_subgraph(subgraph, 1)
  end

  @spec compose_subgraph(t(), non_neg_integer()) :: iodata()
  defp compose_subgraph(
         %__MODULE__{id: id, label: label, direction: direction, entries: entries},
         indent_level
       ) do
    indent = String.duplicate("  ", indent_level)

    [
      indent,
      "subgraph ",
      id,
      if label do
        [" [", label, "]"]
      else
        ""
      end,
      "\n",
      if direction do
        [indent, "  direction ", Map.fetch!(@directions, direction), "\n"]
      else
        []
      end,
      Enum.map(entries, fn entry ->
        compose_entry(entry, indent_level + 1)
      end),
      indent,
      "end\n"
    ]
  end

  @spec compose_entry(Node.t() | Edge.t() | t(), non_neg_integer()) :: iodata()
  defp compose_entry(%__MODULE__{} = subgraph, indent_level) do
    compose_subgraph(subgraph, indent_level)
  end

  defp compose_entry(%Node{} = node, indent_level) do
    composed = Node.compose(node)
    add_indent(composed, indent_level - 1)
  end

  defp compose_entry(%Edge{} = edge, indent_level) do
    composed = Edge.compose(edge)
    add_indent(composed, indent_level - 1)
  end

  @spec add_indent(iodata(), non_neg_integer()) :: iodata()
  defp add_indent(iodata, additional_indent) when additional_indent <= 0, do: iodata

  defp add_indent(iodata, additional_indent) do
    extra_indent = String.duplicate("  ", additional_indent)

    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      if String.trim(line) == "" do
        line
      else
        [extra_indent, line]
      end
    end)
  end
end
