defmodule AshDiagram.Data.PolicySimulationTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias Ash.Policy.Check.ActorPresent
  alias AshDiagram.Data.PolicySimulation
  alias AshDiagram.Flow.Domain
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flowchart
  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style

  defmodule NoPolicyResource do
    @moduledoc false
    use Ash.Resource, domain: Domain

    actions do
      defaults [:read]
    end

    attributes do
      uuid_primary_key :id
    end
  end

  describe "Core Interface" do
    test "generates flowchart for resource with policies" do
      diagram = PolicySimulation.for_resource(Org)

      assert %Flowchart{} = diagram
      assert diagram.direction == :top_bottom
      refute Enum.empty?(diagram.entries)
    end

    test "generates flowchart for resource without policies" do
      diagram = PolicySimulation.for_resource(NoPolicyResource)

      assert %Flowchart{} = diagram

      # Should contain basic flow: start -> forbidden (no policies = always deny)
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      assert Enum.any?(nodes, fn node -> node.id == "start" end)
      assert Enum.any?(nodes, fn node -> node.id == "forbidden" end)
    end

    test "handles custom title option" do
      custom_title = "Custom Policy Simulation"
      diagram = PolicySimulation.for_resource(Org, title: custom_title)

      assert diagram.title == custom_title
    end

    test "handles expansion callback option" do
      expansion_callback = fn
        {ActorPresent, [access_type: :filter]} -> true
        other -> other
      end

      diagram = PolicySimulation.for_resource(Org, expansion_callback: expansion_callback)

      assert %Flowchart{} = diagram
      refute Enum.empty?(diagram.entries)
    end
  end

  describe "Structure and Composition" do
    test "includes required nodes with correct shapes" do
      diagram = PolicySimulation.for_resource(Org)
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))

      # Check for start node
      start_node = Enum.find(nodes, fn node -> node.id == "start" end)
      assert start_node
      assert start_node.shape == :circle

      # Check for authorized result node
      authorized_node = Enum.find(nodes, fn node -> node.id == "authorized" end)
      assert authorized_node
    end

    test "creates proper decision tree connections" do
      diagram = PolicySimulation.for_resource(Org)
      edges = Enum.filter(diagram.entries, &match?(%Edge{}, &1))

      # Should have start edge
      start_edge = Enum.find(edges, fn edge -> edge.from == "start" end)
      assert start_edge

      # Should have edges connecting decision nodes
      check_edges =
        Enum.filter(edges, fn edge ->
          (is_list(edge.from) and String.starts_with?(IO.iodata_to_binary(edge.from), "check_")) or
            (is_list(edge.to) and String.starts_with?(IO.iodata_to_binary(edge.to), "check_"))
        end)

      assert length(check_edges) > 0
    end

    test "includes required style definitions" do
      diagram = PolicySimulation.for_resource(Org)
      styles = Enum.filter(diagram.entries, &match?(%Style{}, &1))

      # Should have class definition for authorized styling
      class_styles = Enum.filter(styles, fn style -> style.type == :class end)
      assert Enum.any?(class_styles, fn style -> style.name == "authorized" end)

      # Should have node style applications
      node_styles = Enum.filter(styles, fn style -> style.type == :node end)
      assert length(node_styles) > 0
    end

    test "creates decision tree structure" do
      diagram = PolicySimulation.for_resource(Org)
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))

      # Should have decision nodes (with iodata IDs starting with "check_")
      check_nodes =
        Enum.filter(nodes, fn node ->
          is_list(node.id) and String.starts_with?(IO.iodata_to_binary(node.id), "check_")
        end)

      assert length(check_nodes) > 0
    end

    test "composes valid Mermaid syntax" do
      diagram = PolicySimulation.for_resource(Org)
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

      # Basic Mermaid flowchart structure
      assert result =~ "flowchart TD"
      assert result =~ "start"
      assert result =~ "authorized"
      assert result =~ "-->"
    end
  end

  describe "Interface Methods" do
    test "for_policies/3 works with explicit policies" do
      policies = Ash.Policy.Info.policies(Org)
      diagram = PolicySimulation.for_policies(Org, policies)

      assert %Flowchart{} = diagram
      refute Enum.empty?(diagram.entries)
    end

    test "for_policies/3 with empty policies" do
      diagram = PolicySimulation.for_policies(Org, [])

      assert %Flowchart{} = diagram

      # Should contain basic flow: start -> forbidden (empty policies = always deny)
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      assert Enum.any?(nodes, fn node -> node.id == "start" end)
      assert Enum.any?(nodes, fn node -> node.id == "forbidden" end)
    end

    test "for_action/3 creates action-specific diagram" do
      read_action = Enum.find(Ash.Resource.Info.actions(Org), &(&1.type == :read))
      diagram = PolicySimulation.for_action(Org, read_action)

      assert %Flowchart{} = diagram
      refute Enum.empty?(diagram.entries)
    end

    test "for_field/3 creates field-specific diagram" do
      diagram = PolicySimulation.for_field(Org, :name)

      assert %Flowchart{} = diagram
    end

    test "for_field/3 raises with invalid field" do
      assert_raise ArgumentError, fn ->
        PolicySimulation.for_field(Org, "invalid_field")
      end
    end
  end

  describe "Visual Tests" do
    @tag :tmp_dir
    test "renders complete resource policy simulation", %{tmp_dir: tmp_dir} do
      diagram =
        PolicySimulation.for_resource(
          Org,
          title: "Complete Resource Policy Simulation"
        )

      assert diagram.title == "Complete Resource Policy Simulation"
      refute Enum.empty?(diagram.entries)

      # Render to PNG
      png = AshDiagram.render(diagram, format: :png, background_color: "white")
      out_path = Path.join(tmp_dir, "complete_resource_policy_simulation.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "complete_resource_policy_simulation_diff.png")

      assert_alike(
        out_path,
        fixture_path("complete_resource_policy_simulation.png"),
        diff_path
      )
    end

    @tag :tmp_dir
    test "renders action-specific policy simulation", %{tmp_dir: tmp_dir} do
      read_action = Enum.find(Ash.Resource.Info.actions(Org), &(&1.type == :read))

      diagram =
        PolicySimulation.for_action(
          Org,
          read_action,
          title: "Action-Specific Policy Simulation"
        )

      assert diagram.title == "Action-Specific Policy Simulation"
      refute Enum.empty?(diagram.entries)

      # Render to PNG
      png = AshDiagram.render(diagram, format: :png, background_color: "white")
      out_path = Path.join(tmp_dir, "action_specific_policy_simulation.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "action_specific_policy_simulation_diff.png")

      assert_alike(
        out_path,
        fixture_path("action_specific_policy_simulation.png"),
        diff_path
      )
    end

    @tag :tmp_dir
    test "renders field-specific policy simulation", %{tmp_dir: tmp_dir} do
      diagram =
        PolicySimulation.for_field(
          Org,
          :name,
          title: "Field-Specific Policy Simulation"
        )

      assert diagram.title == "Field-Specific Policy Simulation"

      # Render to PNG
      png = AshDiagram.render(diagram, format: :png, background_color: "white")
      out_path = Path.join(tmp_dir, "field_specific_policy_simulation.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "field_specific_policy_simulation_diff.png")

      assert_alike(
        out_path,
        fixture_path("field_specific_policy_simulation.png"),
        diff_path
      )
    end

    @tag :tmp_dir
    test "renders false simulation", %{tmp_dir: tmp_dir} do
      read_action = Enum.find(Ash.Resource.Info.actions(Org), &(&1.type == :read))

      diagram =
        PolicySimulation.for_action(
          Org,
          read_action,
          expansion_callback: fn _ -> false end
        )

      # Render to PNG
      png = AshDiagram.render(diagram, format: :png, background_color: "white")
      out_path = Path.join(tmp_dir, "false_simulation.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "false_simulation_diff.png")

      assert_alike(
        out_path,
        fixture_path("false_simulation.png"),
        diff_path
      )
    end

    @tag :tmp_dir
    test "renders true simulation", %{tmp_dir: tmp_dir} do
      read_action = Enum.find(Ash.Resource.Info.actions(Org), &(&1.type == :read))

      diagram =
        PolicySimulation.for_action(
          Org,
          read_action,
          expansion_callback: fn _ -> true end
        )

      # Render to PNG
      png = AshDiagram.render(diagram, format: :png, background_color: "white")
      out_path = Path.join(tmp_dir, "true_simulation.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "true_simulation_diff.png")

      assert_alike(
        out_path,
        fixture_path("true_simulation.png"),
        diff_path
      )
    end
  end
end
