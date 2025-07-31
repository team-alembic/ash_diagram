defmodule AshChartTest do
  use ExUnit.Case, async: true

  import AshChart.Fixture
  import AshChart.VisualAssertions

  alias AshChart.Dummy

  doctest AshChart

  describe inspect(&AshChart.compose/1) do
    test "composs a chart" do
      assert %Dummy{content: "Test Chart Composed"} |> AshChart.compose() |> IO.iodata_to_binary() ==
               "Test Chart Composed"
    end
  end

  describe inspect(&AshChart.compose_markdown/1) do
    test "composs a chart in markdown" do
      assert %Dummy{content: "Test Chart Composed in Markdown"} |> AshChart.compose_markdown() |> IO.iodata_to_binary() ==
               """
               ```mermaid
               Test Chart Composed in Markdown
               ```
               """
    end
  end

  describe inspect(&AshChart.render/1) do
    @tag :tmp_dir
    test "renders a chart", %{tmp_dir: tmp_dir} do
      data = read_fixture("flow.mmd")

      out = AshChart.render(%Dummy{content: data}, format: :png)

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
