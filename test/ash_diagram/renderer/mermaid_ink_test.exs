defmodule AshDiagram.Renderer.MermaidInkTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Renderer.MermaidInk

  doctest MermaidInk

  describe inspect(&MermaidInk.render/2) do
    @tag :tmp_dir
    test "renders a diagram", %{tmp_dir: tmp_dir} do
      data = read_fixture("flow.mmd")

      out = MermaidInk.render(data, format: :png, background_color: "white")

      out_path = Path.join(tmp_dir, "output.png")

      File.write!(out_path, out)

      assert_alike(
        out_path,
        fixture_path("ink-flow.png"),
        Path.join(tmp_dir, "diff.png")
      )
    end
  end
end
