defmodule AshDiagram.Data.ArchitectureTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Data.Architecture
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flow.User

  doctest Architecture

  describe inspect(&Architecture.for_resources/1) do
    @tag :tmp_dir
    test "creates architecture diagram from resources", %{tmp_dir: tmp_dir} do
      diagram = Architecture.for_resources([User, Org])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               C4Context

                 System("dummy", "♡")
                 System_Boundary("beam", "BEAM") {
                   System_Boundary("ash_diagram", "ash_diagram Application") {
                     System_Boundary("ash_diagram_flow_domain", "Domain") {
                       System("ash_diagram_flow_user", "User", "Resource with 9 actions, 1 relationships")
                       System("ash_diagram_flow_org", "Org", "Resource with 6 actions, 1 relationships")
                     }
                   }
                   System_Boundary("ash", "ash Application") {
                     SystemDb("mnesia", "Mnesia", "Mnesia")
                   }
                 }
                 Rel("ash_diagram_flow_org", "ash_diagram_flow_user", "users", "has_many relationship")
                 Rel("ash_diagram_flow_user", "ash_diagram_flow_org", "org", "belongs_to relationship")
                 Rel("ash_diagram_flow_user", "mnesia", "uses", "Stores data")
                 Rel("ash_diagram_flow_org", "mnesia", "uses", "Stores data")
               """

      assert png = AshDiagram.render(diagram, format: :png)

      out_path = Path.join(tmp_dir, "out.png")

      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "diff.png")

      assert_alike(
        out_path,
        fixture_path("architecture.png"),
        diff_path
      )
    end
  end

  describe inspect(&Architecture.for_domains/1) do
    test "creates architecture diagram from domains" do
      diagram = Architecture.for_domains([AshDiagram.Flow.Domain])

      mermaid_output = diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Should be a C4Context diagram by default
      assert mermaid_output =~ "C4Context"

      # Should contain resources from the domain as System elements
      assert mermaid_output =~ ~s(System("ash_diagram_flow_user", "User")
      assert mermaid_output =~ ~s(System("ash_diagram_flow_org", "Org")
    end
  end

  describe inspect(&Architecture.for_applications/1) do
    test "creates architecture diagram from applications" do
      diagram = Architecture.for_applications([:ash_diagram])

      mermaid_output = diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Should be a C4Context diagram showing application-level view
      assert mermaid_output =~ "C4Context"
      # The application name should be "ash_diagram" with proper OTP app name
      assert mermaid_output =~ "ash_diagram"
    end
  end

  describe "relationship filtering" do
    test "only includes relationships between resources in the diagram" do
      # When we create a diagram with only User (not Org),
      # it should NOT include the relationship to Org
      diagram = Architecture.for_resources([User])
      output = diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Should include User
      assert output =~ ~s[System("ash_diagram_flow_user", "User",]

      # Should NOT include any relationships to org (which is not in the diagram)
      refute output =~ "ash_diagram_flow_org"
      refute output =~ ~s[Rel("ash_diagram_flow_user", "ash_diagram_flow_org")]

      # Should still include the data layer relationship
      assert output =~ ~s[Rel("ash_diagram_flow_user", "mnesia", "uses", "Stores data")]
    end

    test "includes relationships when both resources are in the diagram" do
      # When we include both User and Org, relationships should be present
      diagram = Architecture.for_resources([User, Org])
      output = diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Should include both resources
      assert output =~ ~s[System("ash_diagram_flow_user", "User",]
      assert output =~ ~s[System("ash_diagram_flow_org", "Org",]

      # Should include relationships between them
      assert output =~ ~s[Rel("ash_diagram_flow_user", "ash_diagram_flow_org", "org", "belongs_to relationship")]
      assert output =~ ~s[Rel("ash_diagram_flow_org", "ash_diagram_flow_user", "users", "has_many relationship")]
    end
  end

  describe "options" do
    test "supports name option for full vs short names" do
      short_diagram = Architecture.for_resources([User], name: :short)
      full_diagram = Architecture.for_resources([User], name: :full)

      short_output = short_diagram |> AshDiagram.compose() |> IO.iodata_to_binary()
      full_output = full_diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Short names should show just "User" in the label
      assert short_output =~ ~s(System("ash_diagram_flow_user", "User")

      # Full names should show the full module path in the label
      assert full_output =~ ~s(System("ash_diagram_flow_user", "AshDiagram.Flow.User")
    end

    test "supports show_private? option" do
      private_diagram = Architecture.for_resources([User], show_private?: true)
      public_diagram = Architecture.for_resources([User], show_private?: false)

      private_output = private_diagram |> AshDiagram.compose() |> IO.iodata_to_binary()
      public_output = public_diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Both should generate valid diagrams
      assert private_output =~ "C4Context"
      assert public_output =~ "C4Context"
    end

    test "supports title option" do
      default_diagram = Architecture.for_resources([User])
      custom_diagram = Architecture.for_resources([User], title: "Custom Architecture")

      default_output = default_diagram |> AshDiagram.compose() |> IO.iodata_to_binary()
      custom_output = custom_diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

      # Default: no title line
      refute default_output =~ "title"

      # Custom title
      assert custom_output =~ "title Custom Architecture"
    end
  end
end
