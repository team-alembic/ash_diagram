defmodule AshDiagram.Renderer.CLITest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Renderer.CLI

  doctest CLI

  describe inspect(&AshDiagram.render/1) do
    @tag :tmp_dir
    test "renders a diagram", %{tmp_dir: tmp_dir} do
      data = read_fixture("flow.mmd")

      out = CLI.render(data, format: :png)

      out_path = Path.join(tmp_dir, "output.png")

      File.write!(out_path, out)

      assert_alike(
        out_path,
        fixture_path("cli-flow.png"),
        Path.join(tmp_dir, "diff.png")
      )
    end
  end
end
