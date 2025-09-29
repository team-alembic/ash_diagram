readme_path = Path.join(__DIR__, "../README.md")

readme_content =
  readme_path
  |> File.read!()
  |> String.replace(~r/<!-- ex_doc_ignore_start -->.*?<!-- ex_doc_ignore_end -->/s, "")

defmodule AshDiagram do
  @moduledoc """
  #{readme_content}
  """

  alias AshDiagram.Renderer

  @external_resource readme_path

  @typedoc "Module implementing the `AshDiagram.Renderer` behaviour."
  @type implementation() :: module()

  @typedoc "See `t:t/1`."
  @type t() :: t(module())
  @typedoc "Diagram struct where the Struct Module is the implementation module."
  @type t(implementation) :: %{required(:__struct__) => implementation, optional(atom()) => any()}

  @doc """
  Compose the Mermaid diagram from the given `diagram` data structure.
  """
  @callback compose(diagram :: t()) :: iodata()

  @doc """
  Compose the Mermaid diagram as Markdown from the given `diagram` data structure.
  """
  @spec compose(diagram :: t()) :: iodata()
  def compose(%implementation{} = diagram), do: implementation.compose(diagram)

  @doc """
  Compose the Mermaid diagram as Markdown from the given `diagram` data structure.
  """
  @spec compose_markdown(diagram :: t()) :: iodata()
  def compose_markdown(diagram) do
    [
      "```mermaid\n",
      compose(diagram),
      "\n```\n"
    ]
  end

  @doc """
  Render the Mermaid diagram from the given `diagram` data structure.
  """
  @spec render(diagram :: t(), options :: Renderer.options()) :: iodata()
  def render(diagram, options) do
    diagram
    |> compose()
    |> Renderer.render(options)
  end
end
