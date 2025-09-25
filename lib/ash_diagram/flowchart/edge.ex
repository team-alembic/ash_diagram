defmodule AshDiagram.Flowchart.Edge do
  @moduledoc """
  Represents an edge/link between nodes in a flowchart.
  """

  @edge_types %{
    arrow: "-->",
    line: "---",
    dotted_arrow: "-.->",
    dotted_line: "-.-",
    thick_arrow: "==>",
    thick_line: "===",
    invisible: "~~~",
    bidirectional: "<-->",
    circle: "--o",
    cross: "--x"
  }
  @type_labels Map.keys(@edge_types)
  type_typespec = Enum.reduce(@type_labels, &{:|, [], [&1, &2]})
  @type type() :: unquote(type_typespec)

  @type t() :: %__MODULE__{
          from: iodata(),
          to: iodata(),
          type: type(),
          label: iodata() | nil,
          label_style: :pipe | :text | nil,
          style_class: iodata() | nil
        }

  @enforce_keys [:from, :to, :type]
  defstruct [:from, :to, :type, :label, :label_style, :style_class]

  @doc """
  Composes the Mermaid syntax for an edge.
  """
  @spec compose(t()) :: iodata()
  def compose(%__MODULE__{from: from, to: to, type: type, label: label}) do
    [
      "  ",
      from,
      " ",
      compose_edge_syntax(type, label),
      " ",
      to,
      "\n"
    ]
  end

  @spec compose_edge_syntax(type(), iodata() | nil) :: iodata()
  defp compose_edge_syntax(type, label) do
    syntax = Map.fetch!(@edge_types, type)

    if label && label != "" do
      insert_label_in_syntax(syntax, label)
    else
      syntax
    end
  end

  @spec insert_label_in_syntax(String.t(), iodata()) :: iodata()
  defp insert_label_in_syntax(syntax, label) do
    cond do
      String.ends_with?(syntax, ">") ->
        base = String.slice(syntax, 0, String.length(syntax) - 1)
        [base, ">|", label, "|"]

      String.contains?(syntax, "o") or String.contains?(syntax, "x") ->
        [syntax, "|", label, "|"]

      true ->
        [syntax, "|", label, "|"]
    end
  end
end
