defmodule AshDiagram.StubRenderer do
  @moduledoc false
  @behaviour AshDiagram.Renderer

  @impl AshDiagram.Renderer
  def supported?, do: true

  @impl AshDiagram.Renderer
  def render(diagram, options) do
    header = Enum.map_join(options, " ", fn {key, value} -> "#{key}=#{value}" end)
    ["rendered ", header, "\n", diagram]
  end
end
