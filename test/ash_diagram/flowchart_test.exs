defmodule AshDiagram.FlowchartTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Flowchart
  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style
  alias AshDiagram.Flowchart.Subgraph

  doctest Flowchart

  describe inspect(&Flowchart.compose/1) do
    test "renders basic flowchart" do
      diagram = %Flowchart{
        entries: [
          %Node{id: "A", label: "Start"},
          %Node{id: "B", label: "Process", shape: :rectangle},
          %Edge{from: "A", to: "B", type: :arrow}
        ]
      }

      assert diagram |> Flowchart.compose() |> IO.iodata_to_binary() ==
               """
               flowchart TD
                 A[Start]
                 B[Process]
                 A --> B
               """
    end

    test "renders flowchart with title and config" do
      diagram = %Flowchart{
        title: "Sample Process",
        config: %{"theme" => "base", "themeVariables" => %{"primaryColor" => "#ff0000"}},
        entries: [
          %Node{id: "start", label: "Begin"},
          %Node{id: "end", label: "Finish"}
        ]
      }

      assert diagram |> Flowchart.compose() |> IO.iodata_to_binary() ==
               """
               ---
               title: "Sample Process"
               config: {"theme":"base","themeVariables":{"primaryColor":"#ff0000"}}
               ---
               flowchart TD
                 start[Begin]
                 end[Finish]
               """
    end

    test "renders flowchart with direction" do
      diagram = %Flowchart{
        direction: :left_right,
        entries: [
          %Node{id: "A", label: "Left"},
          %Node{id: "B", label: "Right"}
        ]
      }

      assert diagram |> Flowchart.compose() |> IO.iodata_to_binary() ==
               """
               flowchart LR
                 A[Left]
                 B[Right]
               """
    end

    test "renders all direction types" do
      directions = [
        {:top_bottom, "TD"},
        {:bottom_top, "BT"},
        {:left_right, "LR"},
        {:right_left, "RL"}
      ]

      for {direction, expected} <- directions do
        diagram = %Flowchart{
          direction: direction,
          entries: [%Node{id: "A", label: "Node"}]
        }

        result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

        assert result == """
               flowchart #{expected}
                 A[Node]
               """
      end
    end

    test "renders flowchart with subgraph" do
      diagram = %Flowchart{
        entries: [
          %Node{id: "A", label: "Start"},
          %Subgraph{
            id: "sub1",
            label: "Process Group",
            entries: [
              %Node{id: "B", label: "Step 1"},
              %Node{id: "C", label: "Step 2"},
              %Edge{from: "B", to: "C", type: :arrow}
            ]
          },
          %Node{id: "D", label: "End"},
          %Edge{from: "A", to: "B", type: :arrow},
          %Edge{from: "C", to: "D", type: :arrow}
        ]
      }

      assert diagram |> Flowchart.compose() |> IO.iodata_to_binary() ==
               """
               flowchart TD
                 A[Start]
                 subgraph sub1 [Process Group]
                   B[Step 1]
                   C[Step 2]
                   B --> C
                 end
                 D[End]
                 A --> B
                 C --> D
               """
    end

    test "renders complex flowchart with multiple features" do
      diagram = %Flowchart{
        title: "Complex Process Flow",
        direction: :top_bottom,
        entries: [
          %Node{id: "start", label: "Start", shape: :circle},
          %Node{id: "decision", label: "Decision?", shape: :rhombus},
          %Node{id: "process1", label: "Process A", shape: :rectangle},
          %Node{id: "process2", label: "Process B", shape: :rectangle},
          %Node{id: "end", label: "End", shape: :circle},
          %Edge{from: "start", to: "decision", type: :arrow},
          %Edge{from: "decision", to: "process1", type: :arrow, label: "Yes"},
          %Edge{from: "decision", to: "process2", type: :arrow, label: "No"},
          %Edge{from: "process1", to: "end", type: :arrow},
          %Edge{from: "process2", to: "end", type: :arrow},
          %Style{
            type: :class,
            name: "startEnd",
            properties: %{"fill" => "#e1f5fe", "stroke" => "#0277bd"}
          },
          %Style{
            type: :node,
            id: "start",
            classes: ["startEnd"]
          },
          %Style{
            type: :node,
            id: "end",
            classes: ["startEnd"]
          }
        ]
      }

      assert diagram |> Flowchart.compose() |> IO.iodata_to_binary() ==
               """
               ---
               title: "Complex Process Flow"
               ---
               flowchart TD
                 start((Start))
                 decision{Decision?}
                 process1[Process A]
                 process2[Process B]
                 end((End))
                 start --> decision
                 decision -->|Yes| process1
                 decision -->|No| process2
                 process1 --> end
                 process2 --> end
                 classDef startEnd fill:#e1f5fe,stroke:#0277bd
                 class start startEnd
                 class end startEnd
               """
    end

    test "renders flowchart with nested subgraphs" do
      diagram = %Flowchart{
        entries: [
          %Subgraph{
            id: "outer",
            label: "Outer Process",
            entries: [
              %Node{id: "A", label: "Step A"},
              %Subgraph{
                id: "inner",
                label: "Inner Process",
                entries: [
                  %Node{id: "B", label: "Step B1"},
                  %Node{id: "C", label: "Step B2"},
                  %Edge{from: "B", to: "C", type: :arrow}
                ]
              },
              %Edge{from: "A", to: "B", type: :arrow}
            ]
          }
        ]
      }

      assert diagram |> Flowchart.compose() |> IO.iodata_to_binary() ==
               """
               flowchart TD
                 subgraph outer [Outer Process]
                   A[Step A]
                   subgraph inner [Inner Process]
                     B[Step B1]
                     C[Step B2]
                     B --> C
                   end
                   A --> B
                 end
               """
    end
  end

  describe "integration with AshDiagram" do
    test "renders with AshDiagram.render/2" do
      diagram = %Flowchart{
        entries: [
          %Node{id: "A", label: "Test Node"}
        ]
      }

      assert AshDiagram.render(diagram, format: :svg)
    end

    test "composes markdown correctly" do
      diagram = %Flowchart{
        entries: [
          %Node{id: "A", label: "Test Node"}
        ]
      }

      result = diagram |> AshDiagram.compose_markdown() |> IO.iodata_to_binary()

      assert result == """
             ```mermaid
             flowchart TD
               A[Test Node]

             ```
             """
    end

    test "renders complex flowchart with SVG integration" do
      diagram = %Flowchart{
        title: "Complete Feature Implementation",
        config: %{"theme" => "base", "themeVariables" => %{"primaryColor" => "#4CAF50"}},
        direction: :top_bottom,
        entries: [
          %Node{id: "start", label: "Start", shape: :circle},
          %Node{id: "analysis", label: "Requirements Analysis", shape: :rectangle},
          %Node{id: "design_decision", label: "Architecture Decision?", shape: :rhombus},
          %Node{id: "microservice", label: "Microservice Design", shape: :rounded},
          %Node{id: "monolith", label: "Monolithic Design", shape: :rounded},
          %Node{id: "implementation", label: "Implementation Phase", shape: :parallelogram},
          %Node{id: "testing", label: "Testing Suite", shape: :hexagon},
          %Node{id: "deployment_check", label: "Ready for Deploy?", shape: :rhombus},
          %Node{id: "deploy", label: "Deploy to Production", shape: :stadium},
          %Node{id: "monitoring", label: "Monitor & Maintain", shape: :database},
          %Node{id: "end_success", label: "Success", shape: :circle},
          %Node{id: "rollback", label: "Rollback", shape: :trapezoid},
          %Edge{from: "start", to: "analysis", type: :arrow, label: "begin"},
          %Edge{from: "analysis", to: "design_decision", type: :arrow},
          %Edge{from: "design_decision", to: "microservice", type: :arrow, label: "distributed"},
          %Edge{from: "design_decision", to: "monolith", type: :arrow, label: "simple"},
          %Edge{from: "microservice", to: "implementation", type: :dotted_arrow},
          %Edge{from: "monolith", to: "implementation", type: :dotted_arrow},
          %Edge{from: "implementation", to: "testing", type: :thick_arrow, label: "code complete"},
          %Edge{from: "testing", to: "deployment_check", type: :arrow},
          %Edge{from: "deployment_check", to: "deploy", type: :arrow, label: "pass"},
          %Edge{from: "deployment_check", to: "implementation", type: :dotted_arrow, label: "fail"},
          %Edge{from: "deploy", to: "monitoring", type: :arrow},
          %Edge{from: "monitoring", to: "end_success", type: :arrow, label: "stable"},
          %Edge{from: "monitoring", to: "rollback", type: :arrow, label: "issues"},
          %Edge{from: "rollback", to: "implementation", type: :dotted_line, label: "fix & retry"},
          %Subgraph{
            id: "ci_cd",
            label: "CI/CD Pipeline",
            direction: :left_right,
            entries: [
              %Node{id: "build", label: "Build", shape: :subroutine},
              %Node{id: "test_ci", label: "Run Tests", shape: :subroutine},
              %Node{id: "package", label: "Package", shape: :subroutine},
              %Edge{from: "build", to: "test_ci", type: :arrow},
              %Edge{from: "test_ci", to: "package", type: :arrow}
            ]
          },
          %Edge{from: "testing", to: "build", type: :invisible},
          %Edge{from: "package", to: "deploy", type: :invisible},
          %Style{
            type: :class,
            name: "startEnd",
            properties: %{"fill" => "#e8f5e8", "stroke" => "#4CAF50", "stroke-width" => "3px"}
          },
          %Style{type: :class, name: "decision", properties: %{"fill" => "#fff3e0", "stroke" => "#FF9800"}},
          %Style{type: :class, name: "process", properties: %{"fill" => "#e3f2fd", "stroke" => "#2196F3"}},
          %Style{type: :class, name: "danger", properties: %{"fill" => "#ffebee", "stroke" => "#f44336"}},
          %Style{type: :node, id: "start", classes: ["startEnd"]},
          %Style{type: :node, id: "end_success", classes: ["startEnd"]},
          %Style{type: :node, id: "design_decision", classes: ["decision"]},
          %Style{type: :node, id: "deployment_check", classes: ["decision"]},
          %Style{type: :node, id: "implementation", classes: ["process"]},
          %Style{type: :node, id: "testing", classes: ["process"]},
          %Style{type: :node, id: "rollback", classes: ["danger"]},
          %Style{type: :click, id: "deploy", action: "alert('Deploying to production!')"},
          %Style{
            type: :href,
            id: "monitoring",
            url: "https://monitoring.example.com",
            tooltip: "View Monitoring Dashboard"
          }
        ]
      }

      assert AshDiagram.render(diagram, format: :svg)

      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

      assert result =~ "---"
      assert result =~ "title: \"Complete Feature Implementation\""
      assert result =~ ~s(config: {"theme":"base","themeVariables":{"primaryColor":"#4CAF50"}})
      assert result =~ "---"
      assert result =~ "flowchart TD"
      assert result =~ "start((Start))"
      assert result =~ "design_decision{Architecture Decision?}"
      assert result =~ "implementation[/Implementation Phase/]"
      assert result =~ "testing{{Testing Suite}}"
      assert result =~ "deploy([Deploy to Production])"
      assert result =~ "monitoring[(Monitor & Maintain)]"
      assert result =~ "rollback[/Rollback\\]"
      assert result =~ "start -->|begin| analysis"
      assert result =~ "implementation ==>|code complete| testing"
      assert result =~ "monitoring -->|stable| end_success"
      assert result =~ "subgraph ci_cd [CI/CD Pipeline]"
      assert result =~ "direction LR"
      assert result =~ "build[[Build]]"
      assert result =~ "classDef startEnd fill:#e8f5e8,stroke:#4CAF50,stroke-width:3px"
      assert result =~ "class start startEnd"
      assert result =~ "click deploy \"alert('Deploying to production!')\""
      assert result =~ ~s(click monitoring href "https://monitoring.example.com" "View Monitoring Dashboard")
    end
  end
end
