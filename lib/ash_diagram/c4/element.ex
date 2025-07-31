defmodule AshDiagram.C4.Element do
  @moduledoc """
  Represents an element in a C4 diagram.
  """

  alias AshDiagram.C4

  @types %{
    person: "Person",
    system_queue: "SystemQueue",
    system_db: "SystemDb",
    system: "System",
    container_queue: "ContainerQueue",
    container_db: "ContainerDb",
    container: "Container",
    component_queue: "ComponentQueue",
    component_db: "ComponentDb",
    component: "Component"
  }
  @type_keys Map.keys(@types)
  typespec = Enum.reduce(@type_keys, &{:|, [], [&1, &2]})
  @type type() :: unquote(typespec)

  @type t() :: %__MODULE__{
          type: type(),
          external?: boolean(),
          alias: iodata(),
          label: iodata(),
          description: iodata() | nil,
          sprite: iodata() | nil,
          tags: C4.tags() | nil,
          link: iodata() | nil
        }

  @enforce_keys [:type, :external?, :alias, :label]
  defstruct [
    :type,
    :external?,
    :alias,
    :label,
    description: nil,
    sprite: nil,
    tags: nil,
    link: nil
  ]

  @doc false
  @spec compose(element :: t(), indent :: iodata()) :: iodata()
  def compose(%__MODULE__{} = element, indent) do
    [
      indent,
      Map.fetch!(@types, element.type),
      if element.external? do
        "_Ext"
      else
        []
      end,
      C4.compose_attributes([
        {:string, element.alias},
        {:string, element.label},
        {:string, element.description},
        {:string, element.sprite},
        {:map, element.tags},
        {:string, element.link}
      ]),
      "\n"
    ]
  end
end
