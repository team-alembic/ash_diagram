defmodule AshDiagram.DummyExtension do
  @moduledoc false
  @behaviour AshDiagram.Data.Extension

  use Spark.Dsl.Extension

  alias AshDiagram.Data.Extension

  @impl Extension
  def supports?(_creator), do: true

  @impl Extension
  def extend_diagram(creator, diagram)

  def extend_diagram(_creator, %AshDiagram.EntityRelationship{} = diagram) do
    %{
      diagram
      | entries:
          [%AshDiagram.EntityRelationship.Entity{id: "dummy", label: "♡"}] ++ diagram.entries
    }
  end
end
