defmodule AshDiagram.DummyExtension do
  @moduledoc false
  @behaviour AshDiagram.Data.Extension

  use Spark.Dsl.Extension

  alias AshDiagram.Class
  alias AshDiagram.Data.Extension
  alias AshDiagram.EntityRelationship
  alias AshDiagram.Flowchart

  @impl Extension
  def supports?(_creator), do: true

  @impl Extension
  def extend_diagram(creator, diagram)

  def extend_diagram(_creator, %EntityRelationship{} = diagram) do
    %{
      diagram
      | entries: [%EntityRelationship.Entity{id: "dummy", label: "♡"}] ++ diagram.entries
    }
  end

  def extend_diagram(_creator, %Class{} = diagram) do
    %{
      diagram
      | entries: [%Class.Class{id: "dummy", label: "♡"}] ++ diagram.entries
    }
  end

  def extend_diagram(_creator, %Flowchart{} = diagram) do
    %{
      diagram
      | entries: [%Flowchart.Node{id: "dummy", label: "♡", shape: :circle}] ++ diagram.entries
    }
  end
end
