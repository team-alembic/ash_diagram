defmodule AshDiagram.Class.Method do
  @moduledoc """
  Represents a method in the Class Diagram.
  """

  alias AshDiagram.Class.Member

  @type t() :: %__MODULE__{
          visibility: Member.visibility() | nil,
          name: iodata(),
          type: Member.type() | nil,
          abstract: boolean(),
          static: boolean(),
          arguments: [argument()]
        }

  @type argument() :: {iodata(), Member.type() | nil}

  @enforce_keys [:name]
  defstruct [:visibility, :name, :type, abstract: false, static: false, arguments: []]

  @doc false
  @spec compose(entity :: t(), indent :: iodata()) :: iodata()
  def compose(%__MODULE__{name: name} = method, indent \\ []) do
    [
      indent,
      case method.visibility do
        nil -> []
        visibility -> Member.compose_visibility(visibility)
      end,
      name,
      "(",
      compose_arguments(method.arguments),
      ")",
      case method.type do
        nil -> []
        type -> [" : ", Member.compose_type(type)]
      end,
      if method.abstract do
        "*"
      else
        []
      end,
      if method.static do
        "$"
      else
        []
      end
    ]
  end

  @spec compose_arguments(arguments :: [argument()]) :: iodata()
  defp compose_arguments(arguments) do
    arguments
    |> Enum.map(fn {name, type} ->
      [
        if type do
          [Member.compose_type(type), " "]
        else
          []
        end,
        name
      ]
    end)
    |> Enum.intersperse(", ")
  end
end
