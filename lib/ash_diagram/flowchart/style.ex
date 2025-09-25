defmodule AshDiagram.Flowchart.Style do
  @moduledoc """
  Represents styling information for flowchart nodes and edges.
  """

  @type style_type() :: :class | :node | :direct | :click | :href

  @type t() :: %__MODULE__{
          type: style_type(),
          name: iodata() | nil,
          id: iodata() | nil,
          properties: %{String.t() => String.t()} | nil,
          classes: [iodata()] | nil,
          action: iodata() | nil,
          url: iodata() | nil,
          tooltip: iodata() | nil
        }

  @enforce_keys [:type]
  defstruct [:type, :name, :id, :properties, :classes, :action, :url, :tooltip]

  @doc """
  Composes the Mermaid syntax for styling.
  """
  @spec compose(t()) :: iodata()
  def compose(%__MODULE__{type: :class, name: name, properties: properties}) do
    [
      "  classDef ",
      name,
      " ",
      compose_properties(properties || %{}),
      "\n"
    ]
  end

  def compose(%__MODULE__{type: :node, id: id, classes: classes}) do
    [
      "  class ",
      id,
      " ",
      Enum.join(classes || [], ","),
      "\n"
    ]
  end

  def compose(%__MODULE__{type: :direct, id: id, properties: properties}) do
    [
      "  style ",
      id,
      " ",
      compose_properties(properties || %{}),
      "\n"
    ]
  end

  def compose(%__MODULE__{type: :click, id: id, action: action}) do
    [
      "  click ",
      id,
      " \"",
      action,
      "\"\n"
    ]
  end

  def compose(%__MODULE__{type: :href, id: id, url: url, tooltip: tooltip}) do
    [
      "  click ",
      id,
      " href \"",
      url,
      "\"",
      if tooltip do
        [" \"", tooltip, "\""]
      else
        []
      end,
      "\n"
    ]
  end

  @spec compose_properties(%{String.t() => String.t()}) :: iodata()
  defp compose_properties(properties) when properties == %{}, do: ""

  defp compose_properties(properties) do
    properties
    |> Enum.sort()
    |> Enum.map_join(",", fn {key, value} -> "#{key}:#{value}" end)
  end
end
