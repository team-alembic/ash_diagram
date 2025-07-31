defmodule AshDiagram.C4Test do
  use ExUnit.Case, async: true

  alias AshDiagram.C4

  describe inspect(&C4.compose/1) do
    test "renders a valid C4 diagram" do
      diagram = %C4{
        type: :c4_context,
        title: "Test Context",
        entries: [
          %C4.Boundary{
            type: :boundary,
            alias: "System",
            label: "System Boundary",
            entries: [
              %C4.Element{type: :system, alias: "System DB", label: "System Database", external?: false}
            ]
          },
          %C4.Element{type: :person, alias: "User", label: "User Element", external?: false},
          %C4.Relationship{type: :rel, from: "User", to: "System DB", label: "Uses", technology: "SQL"}
        ]
      }

      assert diagram |> C4.compose() |> IO.iodata_to_binary() == """
             C4Context
               title Test Context

               Boundary("System", "System Boundary") {
                 System("System DB", "System Database")
               }
               Person("User", "User Element")
               Rel("User", "System DB", "Uses", "SQL")
             """

      assert AshDiagram.render(diagram, format: :svg)
    end
  end
end
