defmodule AshChart.Renderer.MermaidInkTest do
  use ExUnit.Case, async: true

  import AshChart.Fixture
  import AshChart.VisualAssertions

  alias AshChart.Renderer.MermaidInk

  doctest MermaidInk

  doctest AshChart

  describe inspect(&MermaidInk.render/2) do
    @tag :tmp_dir
    test "renders a chart", %{tmp_dir: tmp_dir} do
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
