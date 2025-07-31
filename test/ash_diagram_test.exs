defmodule AshDiagramTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Dummy

  doctest AshDiagram

  describe inspect(&AshDiagram.compose/1) do
    test "composs a diagram" do
      assert %Dummy{content: "Test Diagram Composed"} |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               "Test Diagram Composed"
    end
  end

  describe inspect(&AshDiagram.compose_markdown/1) do
    test "composs a diagram in markdown" do
      assert %Dummy{content: "Test Diagram Composed in Markdown"}
             |> AshDiagram.compose_markdown()
             |> IO.iodata_to_binary() ==
               """
               ```mermaid
               Test Diagram Composed in Markdown
               ```
               """
    end
  end

  describe inspect(&AshDiagram.render/1) do
    @tag :tmp_dir
    test "renders a diagram", %{tmp_dir: tmp_dir} do
      data = read_fixture("flow.mmd")

      out = AshDiagram.render(%Dummy{content: data}, format: :png)

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
