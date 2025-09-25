defmodule AshDiagram.Flowchart.SubgraphTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Subgraph

  doctest Subgraph

  describe inspect(&Subgraph.compose/1) do
    test "renders basic subgraph with label" do
      subgraph = %Subgraph{
        id: "sub1",
        label: "Process Group",
        entries: [
          %Node{id: "A", label: "Step 1"},
          %Node{id: "B", label: "Step 2"}
        ]
      }

      assert subgraph |> Subgraph.compose() |> IO.iodata_to_binary() ==
               """
                 subgraph sub1 [Process Group]
                   A[Step 1]
                   B[Step 2]
                 end
               """
    end

    test "renders subgraph without label" do
      subgraph = %Subgraph{
        id: "sub1",
        entries: [
          %Node{id: "A", label: "Node A"}
        ]
      }

      assert subgraph |> Subgraph.compose() |> IO.iodata_to_binary() ==
               """
                 subgraph sub1
                   A[Node A]
                 end
               """
    end

    test "renders subgraph with direction" do
      subgraph = %Subgraph{
        id: "horizontal",
        direction: :left_right,
        entries: [
          %Node{id: "left", label: "Left"},
          %Node{id: "right", label: "Right"}
        ]
      }

      assert subgraph |> Subgraph.compose() |> IO.iodata_to_binary() ==
               """
                 subgraph horizontal
                   direction LR
                   left[Left]
                   right[Right]
                 end
               """
    end

    test "renders nested subgraph" do
      subgraph = %Subgraph{
        id: "outer",
        entries: [
          %Node{id: "A", label: "Start"},
          %Subgraph{
            id: "inner",
            label: "Inner",
            entries: [
              %Node{id: "B", label: "Inner Node"}
            ]
          }
        ]
      }

      assert subgraph |> Subgraph.compose() |> IO.iodata_to_binary() ==
               """
                 subgraph outer
                   A[Start]
                   subgraph inner [Inner]
                     B[Inner Node]
                   end
                 end
               """
    end

    test "renders empty subgraph" do
      subgraph = %Subgraph{
        id: "empty",
        entries: []
      }

      assert subgraph |> Subgraph.compose() |> IO.iodata_to_binary() ==
               """
                 subgraph empty
                 end
               """
    end

    test "quotes subgraph ID with spaces" do
      subgraph = %Subgraph{
        id: "my subgraph",
        entries: []
      }

      result = subgraph |> Subgraph.compose() |> IO.iodata_to_binary()

      assert result == """
               subgraph my subgraph
               end
             """
    end

    test "renders subgraph with edges" do
      subgraph = %Subgraph{
        id: "connected",
        entries: [
          %Node{id: "A", label: "Node A"},
          %Node{id: "B", label: "Node B"},
          %Edge{from: "A", to: "B", type: :arrow}
        ]
      }

      result = subgraph |> Subgraph.compose() |> IO.iodata_to_binary()

      assert result == """
               subgraph connected
                 A[Node A]
                 B[Node B]
                 A --> B
               end
             """
    end
  end
end
