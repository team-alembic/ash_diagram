defmodule AshDiagram.Flowchart.NodeTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Flowchart.Node

  doctest Node

  describe inspect(&Node.compose/1) do
    test "renders rectangle node (default)" do
      node = %Node{id: "A", label: "Rectangle"}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  A[Rectangle]\n"
    end

    test "renders rectangle node explicitly" do
      node = %Node{id: "rect", label: "Rectangle", shape: :rectangle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  rect[Rectangle]\n"
    end

    test "renders rounded rectangle node" do
      node = %Node{id: "round", label: "Rounded", shape: :rounded}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  round(Rounded)\n"
    end

    test "renders stadium node" do
      node = %Node{id: "stadium", label: "Stadium", shape: :stadium}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  stadium([Stadium])\n"
    end

    test "renders circle node" do
      node = %Node{id: "circle", label: "Circle", shape: :circle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  circle((Circle))\n"
    end

    test "renders rhombus node" do
      node = %Node{id: "diamond", label: "Decision", shape: :rhombus}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  diamond{Decision}\n"
    end

    test "renders hexagon node" do
      node = %Node{id: "hex", label: "Process", shape: :hexagon}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  hex{{Process}}\n"
    end

    test "renders parallelogram node" do
      node = %Node{id: "para", label: "Input/Output", shape: :parallelogram}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  para[/Input/Output/]\n"
    end

    test "renders parallelogram alt node" do
      node = %Node{id: "paraalt", label: "Alt I/O", shape: :parallelogram_alt}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  paraalt[\\Alt I/O\\]\n"
    end

    test "renders trapezoid node" do
      node = %Node{id: "trap", label: "Manual", shape: :trapezoid}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  trap[/Manual\\]\n"
    end

    test "renders trapezoid alt node" do
      node = %Node{id: "trapalt", label: "Alt Manual", shape: :trapezoid_alt}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  trapalt[\\Alt Manual/]\n"
    end

    test "renders database node" do
      node = %Node{id: "db", label: "Database", shape: :database}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  db[(Database)]\n"
    end

    test "renders cylindrical node" do
      node = %Node{id: "cyl", label: "Cylinder", shape: :cylindrical}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  cyl[[Cylinder]]\n"
    end

    test "renders subroutine node" do
      node = %Node{id: "sub", label: "Subroutine", shape: :subroutine}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  sub[[Subroutine]]\n"
    end

    test "renders flag node" do
      node = %Node{id: "flag", label: "Flag", shape: :flag}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  flag>Flag]\n"
    end

    test "renders lean right node" do
      node = %Node{id: "lean", label: "Lean", shape: :lean_right}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  lean>/Lean/]\n"
    end

    test "renders lean left node" do
      node = %Node{id: "leanleft", label: "Lean Left", shape: :lean_left}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  leanleft[\\Lean Left\\]\n"
    end

    test "renders node without label" do
      node = %Node{id: "no_label", shape: :rectangle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  no_label\n"
    end

    test "renders node with spaces in ID" do
      node = %Node{id: "node with spaces", label: "Spaced", shape: :rectangle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  node with spaces[Spaced]\n"
    end

    test "renders node with markdown in label" do
      node = %Node{id: "md", label: "**Bold** and *italic*", shape: :rectangle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  md[**Bold** and *italic*]\n"
    end

    test "renders node with unicode characters" do
      node = %Node{id: "unicode", label: "🚀 Unicode Test ✓", shape: :circle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  unicode((🚀 Unicode Test ✓))\n"
    end

    test "renders node with multiline label" do
      node = %Node{id: "multi", label: "Line 1\nLine 2\nLine 3", shape: :rectangle}

      result = node |> Node.compose() |> IO.iodata_to_binary()
      assert result =~ "multi["
      assert result =~ "Line 1"
      assert result =~ "Line 2"
      assert result =~ "Line 3"
    end

    test "renders node with empty label" do
      node = %Node{id: "empty", label: "", shape: :rectangle}

      assert node |> Node.compose() |> IO.iodata_to_binary() == "  empty[]\n"
    end

    test "renders all supported shapes" do
      node1 = %Node{id: "test", label: "Label", shape: :rectangle}
      assert node1 |> Node.compose() |> IO.iodata_to_binary() == "  test[Label]\n"

      node2 = %Node{id: "test", label: "Label", shape: :circle}
      assert node2 |> Node.compose() |> IO.iodata_to_binary() == "  test((Label))\n"

      node3 = %Node{id: "test", label: "Label", shape: :rhombus}
      assert node3 |> Node.compose() |> IO.iodata_to_binary() == "  test{Label}\n"

      node4 = %Node{id: "test", label: "Label", shape: :stadium}
      assert node4 |> Node.compose() |> IO.iodata_to_binary() == "  test([Label])\n"
    end

    test "handles ID sanitization for mermaid compatibility" do
      node1 = %Node{id: "with-dashes", label: "Test"}
      assert node1 |> Node.compose() |> IO.iodata_to_binary() == "  with-dashes[Test]\n"

      node2 = %Node{id: "with spaces", label: "Test"}
      assert node2 |> Node.compose() |> IO.iodata_to_binary() == "  with spaces[Test]\n"

      node3 = %Node{id: "with.dots", label: "Test"}
      assert node3 |> Node.compose() |> IO.iodata_to_binary() == "  with.dots[Test]\n"
    end
  end
end
