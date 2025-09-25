defmodule AshDiagram.C4 do
  @moduledoc """
  Provides functions to handle Mermaid
  [C4 Diagrams](https://mermaid.js.org/syntax/c4.html).
  """

  @behaviour AshDiagram

  alias AshDiagram.C4.Boundary
  alias AshDiagram.C4.Element
  alias AshDiagram.C4.Relationship
  alias AshDiagram.C4.RelationshipIndex

  @types %{
    c4_context: "C4Context",
    c4_container: "C4Container",
    c4_component: "C4Component",
    c4_dynamic: "C4Dynamic",
    c4_deployment: "C4Deployment"
  }
  @type_keys Map.keys(@types)
  typespec = Enum.reduce(@type_keys, &{:|, [], [&1, &2]})
  @type type() :: unquote(typespec)

  @type t() :: %__MODULE__{
          type: type(),
          title: iodata(),
          entries: nonempty_list(entry())
        }

  @type tags() :: [{iodata(), iodata()}]

  @type entry() :: Element.t() | Boundary.t() | Relationship.t() | RelationshipIndex.t()

  @doc false
  @type attribute() ::
          {:index, non_neg_integer() | nil}
          | {:string, iodata() | nil}
          | {:map, [{iodata(), attribute()}] | nil}

  @enforce_keys [:type, :title, :entries]
  defstruct [:type, :title, :entries]

  @impl AshDiagram
  def compose(%__MODULE__{type: type, title: title, entries: entries} = _diagram) do
    [
      Map.fetch!(@types, type),
      "\n",
      if IO.iodata_length(title) > 0 do
        [
          "  title ",
          title,
          "\n"
        ]
      else
        []
      end,
      "\n",
      Enum.map(entries, &compose_entry(&1, "  "))
    ]
  end

  @doc false
  @spec compose_entry(entry :: entry(), indent :: iodata()) :: iodata()
  def compose_entry(%mod{} = element, indent), do: mod.compose(element, indent)

  @doc false
  @spec compose_attributes(attributes :: [attribute()]) :: iodata()
  def compose_attributes(attributes) do
    [
      "(",
      attributes
      |> Enum.reject(fn
        {_type, nil} -> true
        {:map, []} -> true
        _other -> false
      end)
      |> Enum.flat_map(&compose_attribute/1)
      |> Enum.intersperse(", "),
      ")"
    ]
  end

  @spec compose_attribute(attribute :: attribute()) :: iodata()
  defp compose_attribute(attribute)
  defp compose_attribute({:string, string}), do: [string |> IO.iodata_to_binary() |> inspect()]

  defp compose_attribute({:map, map}) do
    Enum.map(map, fn {key, value} ->
      [key, "=", compose_attribute(value)]
    end)
  end
end
