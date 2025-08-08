defmodule AshDiagram.Data.Extension do
  @moduledoc """
  Provides functions to extend AshDiagram generated diagrams.

  Can be implemented in spark extensions to resources and domains to add custom
  data to the diagrams.
  """

  @type creator() :: AshDiagram.Data.EntityRelationship

  @doc """
  Checks if the extension creator supports the given creator.

  Returns `true` if the creator is supported, `false` otherwise.

  The function can add additional creators over time, `false` must be returned
  for all creators that are not supported.
  """
  @callback supports?(creator :: creator()) :: boolean()
  @callback supports?(creator :: module()) :: false

  @doc """
  Extends the diagram with additional data.
  The function should return the extended diagram.
  """
  @callback extend_diagram(
              creator :: creator(),
              diagram :: AshDiagram.t(implementation)
            ) :: AshDiagram.t(implementation)
            when implementation: AshDiagram.implementation()

  @doc false
  @spec construct_diagram(
          creator :: creator(),
          extensions :: [module()],
          diagram :: AshDiagram.t()
        ) :: AshDiagram.t()
  def construct_diagram(creator, extensions, diagram) do
    for extension <- extensions,
        Spark.implements_behaviour?(extension, __MODULE__),
        extension.supports?(creator),
        reduce: diagram do
      diagram -> extension.extend_diagram(creator, diagram)
    end
  end
end
