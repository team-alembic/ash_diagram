defmodule AshChart do
  @moduledoc """
  AshChart is a library for rendering charts to introspect your Ash application.
  """

  alias AshChart.Renderer

  @typedoc "Module implementing the `AshChart.Renderer` behaviour."
  @type implementation() :: module()

  @typedoc "See `t:t/1`."
  @type t() :: t(module())
  @typedoc "Chart struct where the Struct Module is the implementation module."
  @type t(implementation) :: %{required(:__struct__) => implementation, optional(atom()) => any()}

  @doc """
  Compose the Mermaid chart from the given `chart` data structure.
  """
  @callback compose(chart :: t()) :: iodata()

  @doc """
  Compose the Mermaid chart as Markdown from the given `chart` data structure.
  """
  @spec compose(chart :: t()) :: iodata()
  def compose(%implementation{} = chart), do: implementation.compose(chart)

  @doc """
  Compose the Mermaid chart as Markdown from the given `chart` data structure.
  """
  @spec compose_markdown(chart :: t()) :: iodata()
  def compose_markdown(chart) do
    [
      "```mermaid\n",
      compose(chart),
      "\n```\n"
    ]
  end

  @doc """
  Render the Mermaid chart from the given `chart` data structure.
  """
  @spec render(chart :: t(), options :: Renderer.options()) :: iodata()
  def render(chart, options) do
    chart
    |> compose()
    |> Renderer.render(options)
  end
end
