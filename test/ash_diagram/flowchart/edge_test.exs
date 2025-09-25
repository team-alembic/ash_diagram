defmodule AshDiagram.Flowchart.EdgeTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Flowchart.Edge

  doctest Edge

  describe inspect(&Edge.compose/1) do
    test "renders basic arrow edge" do
      edge = %Edge{from: "A", to: "B", type: :arrow}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A --> B\n"
    end

    test "renders solid line edge" do
      edge = %Edge{from: "A", to: "B", type: :line}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A --- B\n"
    end

    test "renders dotted arrow edge" do
      edge = %Edge{from: "A", to: "B", type: :dotted_arrow}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A -.-> B\n"
    end

    test "renders dotted line edge" do
      edge = %Edge{from: "A", to: "B", type: :dotted_line}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A -.- B\n"
    end

    test "renders thick arrow edge" do
      edge = %Edge{from: "A", to: "B", type: :thick_arrow}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A ==> B\n"
    end

    test "renders thick line edge" do
      edge = %Edge{from: "A", to: "B", type: :thick_line}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A === B\n"
    end

    test "renders invisible edge" do
      edge = %Edge{from: "A", to: "B", type: :invisible}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A ~~~ B\n"
    end

    test "renders multidirectional arrow" do
      edge = %Edge{from: "A", to: "B", type: :bidirectional}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A <--> B\n"
    end

    test "renders circle edge" do
      edge = %Edge{from: "A", to: "B", type: :circle}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A --o B\n"
    end

    test "renders cross edge" do
      edge = %Edge{from: "A", to: "B", type: :cross}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A --x B\n"
    end

    test "renders edge with label" do
      edge = %Edge{from: "A", to: "B", type: :arrow, label: "process"}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A -->|process| B\n"
    end

    test "renders edge with label using text syntax" do
      edge = %Edge{from: "A", to: "B", type: :line, label: "connects", label_style: :text}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A ---|connects| B\n"
    end

    test "renders dotted edge with label" do
      edge = %Edge{from: "A", to: "B", type: :dotted_arrow, label: "optional"}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A -.->|optional| B\n"
    end

    test "renders thick edge with label" do
      edge = %Edge{from: "A", to: "B", type: :thick_arrow, label: "important"}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A ==>|important| B\n"
    end

    test "renders edge with spaces in node IDs" do
      edge = %Edge{from: "node A", to: "node B", type: :arrow}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  node A --> node B\n"
    end

    test "renders edge with unicode in label" do
      edge = %Edge{from: "A", to: "B", type: :arrow, label: "🚀 Process ✓"}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A -->|🚀 Process ✓| B\n"
    end

    test "renders all supported edge types" do
      edge_types_and_syntax = [
        {:arrow, "-->"},
        {:line, "---"},
        {:dotted_arrow, "-.->"},
        {:dotted_line, "-.-"},
        {:thick_arrow, "==>"},
        {:thick_line, "==="},
        {:invisible, "~~~"},
        {:bidirectional, "<-->"},
        {:circle, "--o"},
        {:cross, "--x"}
      ]

      for {type, expected_syntax} <- edge_types_and_syntax do
        edge = %Edge{from: "A", to: "B", type: type}
        result = edge |> Edge.compose() |> IO.iodata_to_binary()
        assert result == "  A #{expected_syntax} B\n"
      end
    end

    test "handles empty label gracefully" do
      edge = %Edge{from: "A", to: "B", type: :arrow, label: ""}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A --> B\n"
    end

    test "handles nil label gracefully" do
      edge = %Edge{from: "A", to: "B", type: :arrow, label: nil}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() == "  A --> B\n"
    end

    test "renders edge with custom styling" do
      edge = %Edge{from: "A", to: "B", type: :arrow, style_class: "important"}

      assert edge |> Edge.compose() |> IO.iodata_to_binary() ==
               "  A --> B\n"
    end
  end

  describe "validation" do
    test "validates supported edge types" do
      valid_types = [
        :arrow,
        :line,
        :dotted_arrow,
        :dotted_line,
        :thick_arrow,
        :thick_line,
        :invisible,
        :bidirectional,
        :circle,
        :cross
      ]

      for type <- valid_types do
        edge = %Edge{from: "A", to: "B", type: type}
        result = edge |> Edge.compose() |> IO.iodata_to_binary()
        assert result =~ "A"
        assert result =~ "B"
      end
    end
  end

  describe "ID sanitization" do
    test "handles special characters in node IDs" do
      edge1 = %Edge{from: "simple", to: "B", type: :arrow}
      assert edge1 |> Edge.compose() |> IO.iodata_to_binary() == "  simple --> B\n"

      edge2 = %Edge{from: "with space", to: "B", type: :arrow}
      assert edge2 |> Edge.compose() |> IO.iodata_to_binary() == "  with space --> B\n"

      edge3 = %Edge{from: "with.dot", to: "B", type: :arrow}
      assert edge3 |> Edge.compose() |> IO.iodata_to_binary() == "  with.dot --> B\n"
    end
  end
end
