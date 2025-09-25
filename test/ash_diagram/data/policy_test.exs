defmodule AshDiagram.Data.PolicyTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Data.Policy
  alias AshDiagram.Flow.Domain
  alias AshDiagram.Flow.MultipleConditionalPoliciesResource
  alias AshDiagram.Flow.OptimizationTestResource
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flow.User
  alias AshDiagram.Flowchart
  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style
  alias AshDiagram.Flowchart.Subgraph

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

  defmodule SimpleResource do
    @moduledoc false
    use Ash.Resource, domain: Domain

    actions do
      defaults [:read]
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string
    end
  end

  describe inspect(&Policy.for_resource/2) do
    test "generates flowchart for resource with policies" do
      diagram = Policy.for_resource(User)

      assert %Flowchart{} = diagram
      assert diagram.title =~ "Policy Flow: AshDiagram.Flow.User"
      assert diagram.direction == :top_bottom
      refute Enum.empty?(diagram.entries)
    end

    test "generates flowchart for resource without policies" do
      diagram = Policy.for_resource(SimpleResource)

      assert %Flowchart{} = diagram
      assert diagram.title =~ "(No Policies)"

      # Should contain basic flow: start -> no policies -> authorized
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      assert Enum.any?(nodes, fn node -> node.id == "start" end)
      assert Enum.any?(nodes, fn node -> node.id == "no_policies" end)
      assert Enum.any?(nodes, fn node -> node.id == "authorized" end)
    end

    test "includes start node and result nodes" do
      diagram = Policy.for_resource(User)

      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))

      # Check for start node
      start_node = Enum.find(nodes, fn node -> node.id == "start" end)
      assert start_node
      assert start_node.shape == :circle

      # Check for result subgraph
      subgraphs = Enum.filter(diagram.entries, &match?(%Subgraph{}, &1))
      results_subgraph = Enum.find(subgraphs, fn sg -> sg.id == "results" end)
      assert results_subgraph
      assert results_subgraph.label == "Results"
    end

    test "creates condition nodes with rhombus shape" do
      diagram = Policy.for_resource(User)

      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      condition_nodes = Enum.filter(nodes, fn node -> String.ends_with?(node.id, "_conditions") end)

      assert length(condition_nodes) > 0

      Enum.each(condition_nodes, fn node ->
        assert node.shape == :rhombus
        assert is_binary(node.label)
      end)
    end

    test "creates check nodes with rhombus shape" do
      diagram = Policy.for_resource(User)

      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      check_nodes = Enum.filter(nodes, fn node -> String.contains?(node.id, "_checks_") end)

      assert length(check_nodes) > 0

      Enum.each(check_nodes, fn node ->
        assert node.shape == :rhombus
        assert is_binary(node.label)
      end)
    end

    test "includes policy flow edges with True/False labels" do
      diagram = Policy.for_resource(User)

      edges = Enum.filter(diagram.entries, &match?(%Edge{}, &1))
      labeled_edges = Enum.filter(edges, fn edge -> edge.label in ["True", "False"] end)

      assert length(labeled_edges) > 0
    end

    test "creates style definitions for results" do
      diagram = Policy.for_resource(User)

      styles = Enum.filter(diagram.entries, &match?(%Style{}, &1))

      # Should have class definitions for authorized/forbidden styling
      class_styles = Enum.filter(styles, fn style -> style.type == :class end)
      assert Enum.any?(class_styles, fn style -> style.name == "authorized" end)
      assert Enum.any?(class_styles, fn style -> style.name == "forbidden" end)

      # Should have node style applications
      node_styles = Enum.filter(styles, fn style -> style.type == :node end)
      assert length(node_styles) > 0
    end

    test "handles custom title option" do
      custom_title = "Custom Policy Flow Chart"
      diagram = Policy.for_resource(User, title: custom_title)

      assert diagram.title == custom_title
    end

    test "handles simplify option" do
      # Test with simplify disabled
      diagram_complex = Policy.for_resource(User, simplify?: false)
      assert %Flowchart{} = diagram_complex

      # Test with simplify enabled (default)
      diagram_simple = Policy.for_resource(User, simplify?: true)
      assert %Flowchart{} = diagram_simple
    end

    test "generates flowchart for complex organization policies" do
      diagram = Policy.for_resource(Org)

      assert %Flowchart{} = diagram
      assert diagram.title =~ "Policy Flow: AshDiagram.Flow.Org"

      # Should generate valid structure
      assert length(diagram.entries) > 0
    end
  end

  describe "policy parsing and representation" do
    test "correctly represents authorize_if policies" do
      diagram = Policy.for_resource(User)

      # Find edges that should represent authorize_if logic
      edges = Enum.filter(diagram.entries, &match?(%Edge{}, &1))
      true_edges = Enum.filter(edges, fn edge -> edge.label == "True" end)

      # Should have True paths that lead toward authorization
      assert length(true_edges) > 0
    end

    test "correctly represents forbid_if policies" do
      diagram = Policy.for_resource(User)

      # Should have nodes representing forbid conditions
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      check_nodes = Enum.filter(nodes, fn node -> String.contains?(node.id, "_checks_") end)

      # At least some check nodes should exist (forbid_if policies create checks)
      assert length(check_nodes) > 0
    end

    test "handles bypass policies correctly" do
      diagram = Policy.for_resource(User)

      # Bypass policies should still generate nodes and edges
      nodes = Enum.filter(diagram.entries, &match?(%Node{}, &1))
      edges = Enum.filter(diagram.entries, &match?(%Edge{}, &1))

      assert length(nodes) > 0
      assert length(edges) > 0
    end
  end

  describe "optimization features" do
    test "optimization features work correctly" do
      # Test with simplify disabled
      unoptimized = Policy.for_resource(OptimizationTestResource, simplify?: false)

      # Test with simplify enabled
      optimized = Policy.for_resource(OptimizationTestResource, simplify?: true)

      # Both should generate valid diagrams
      assert %Flowchart{} = unoptimized
      assert %Flowchart{} = optimized

      # Both should compose to valid Mermaid
      unoptimized_result = unoptimized |> Flowchart.compose() |> IO.iodata_to_binary()
      optimized_result = optimized |> Flowchart.compose() |> IO.iodata_to_binary()

      assert unoptimized_result =~ "flowchart TD"
      assert optimized_result =~ "flowchart TD"

      # Optimized version should be valid
      assert optimized_result =~ "start"
      assert optimized_result =~ "authorized"
      assert optimized_result =~ "forbidden"
    end

    test "handles special characters in policy descriptions" do
      diagram = Policy.for_resource(OptimizationTestResource)
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

      # Should handle special characters without errors
      assert result =~ "special_chars"
      assert result =~ "flowchart TD"
    end
  end

  describe "'at least one policy applies' logic" do
    test "creates 'at least one policy' check for multiple conditional policies" do
      diagram = Policy.for_resource(MultipleConditionalPoliciesResource)
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

      # Should have "at least one policy applies" subgraph
      assert result =~ "at least one policy applies"
      assert result =~ "at_least_one_policy_check"

      # Should have proper routing from start to policy check
      assert result =~ "start --> at_least_one_policy_check"
      assert result =~ "at_least_one_policy_check -->|False| forbidden"
      assert result =~ "at_least_one_policy_check -->|True|"
    end

    test "handles single conditional policy without 'at least one policy' logic" do
      diagram = Policy.for_resource(User)
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

      # Should generate valid flowchart
      assert result =~ "flowchart TD"
      assert result =~ "start"
    end
  end

  describe "integration with AshDiagram" do
    test "composes valid Mermaid syntax" do
      diagram = Policy.for_resource(User)

      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()

      # Basic Mermaid flowchart structure
      assert result =~ "flowchart TD"
      assert result =~ "start"
      assert result =~ "authorized"
      assert result =~ "forbidden"
      assert result =~ "-->"
    end

    test "renders with AshDiagram.render/2" do
      diagram = Policy.for_resource(User)

      # Should not raise an error when rendering
      assert AshDiagram.render(diagram, format: :svg)
    end

    test "composes markdown correctly" do
      diagram = Policy.for_resource(User)

      result = diagram |> AshDiagram.compose_markdown() |> IO.iodata_to_binary()

      assert result =~ "```mermaid"
      assert result =~ "flowchart TD"
      assert result =~ "```"
    end
  end

  describe "edge cases and error handling" do
    test "handles resources without policy extension gracefully" do
      # Should not raise an error
      diagram = Policy.for_resource(NoPolicyResource)
      assert %Flowchart{} = diagram
    end

    test "handles mixed static and dynamic conditions" do
      # The OptimizationTestResource has both static and dynamic conditions
      diagram = Policy.for_resource(OptimizationTestResource, simplify?: true)

      # Should handle both types without errors
      assert %Flowchart{} = diagram
      assert diagram.title =~ "OptimizationTestResource"
    end

    test "optimization doesn't break basic functionality" do
      # Test that optimized diagrams still work with AshDiagram infrastructure
      diagram = Policy.for_resource(OptimizationTestResource, simplify?: true)

      # Should compose to valid Mermaid
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()
      assert result =~ "flowchart TD"

      # Should work with markdown composition
      markdown = diagram |> AshDiagram.compose_markdown() |> IO.iodata_to_binary()
      assert markdown =~ "```mermaid"
      assert markdown =~ "```"
    end
  end

  describe "Visual Policy Flow Charts" do
    @tag :tmp_dir
    test "renders complex organization policy flow", %{tmp_dir: tmp_dir} do
      # Generate complex policy diagram for Org resource
      diagram = Policy.for_resource(Org, title: "Complex Organization Policies")

      # Verify we have substantial content
      assert diagram.title == "Complex Organization Policies"
      refute Enum.empty?(diagram.entries)

      # Render to PNG
      assert png = AshDiagram.render(diagram, format: :png, background_color: "white")

      # Save and compare
      out_path = Path.join(tmp_dir, "org_policy_complex.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "org_policy_complex_diff.png")

      assert_alike(
        out_path,
        fixture_path("org_policy_complex.png"),
        diff_path
      )
    end

    @tag :tmp_dir
    test "renders multiple conditional policies resource", %{tmp_dir: tmp_dir} do
      # This resource tests the "at least one policy applies" logic
      diagram =
        Policy.for_resource(MultipleConditionalPoliciesResource,
          title: "Multiple Conditional Policies Flow"
        )

      assert diagram.title == "Multiple Conditional Policies Flow"

      # Should contain "at least one policy" logic
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()
      assert result =~ "at least one policy applies"

      # Render to PNG
      assert png = AshDiagram.render(diagram, format: :png, background_color: "white")

      out_path = Path.join(tmp_dir, "multiple_conditional_policies.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "multiple_conditional_policies_diff.png")

      assert_alike(
        out_path,
        fixture_path("multiple_conditional_policies.png"),
        diff_path
      )
    end

    @tag :tmp_dir
    test "renders optimization test resource with simplification", %{tmp_dir: tmp_dir} do
      # Test both simplified and non-simplified versions
      diagram_simple =
        Policy.for_resource(OptimizationTestResource,
          simplify?: true,
          title: "Optimized Policy Flow"
        )

      diagram_complex =
        Policy.for_resource(OptimizationTestResource,
          simplify?: false,
          title: "Non-Optimized Policy Flow"
        )

      # Render simplified version
      png_simple = AshDiagram.render(diagram_simple, format: :png, background_color: "white")
      simple_path = Path.join(tmp_dir, "optimization_simple.png")
      File.write!(simple_path, png_simple)

      # Render complex version
      png_complex = AshDiagram.render(diagram_complex, format: :png, background_color: "white")
      complex_path = Path.join(tmp_dir, "optimization_complex.png")
      File.write!(complex_path, png_complex)

      # Compare both versions
      simple_diff_path = Path.join(tmp_dir, "optimization_simple_diff.png")
      complex_diff_path = Path.join(tmp_dir, "optimization_complex_diff.png")

      assert_alike(
        simple_path,
        fixture_path("optimization_simple.png"),
        simple_diff_path
      )

      assert_alike(
        complex_path,
        fixture_path("optimization_complex.png"),
        complex_diff_path
      )
    end

    @tag :tmp_dir
    test "renders policy diagram with special characters", %{tmp_dir: tmp_dir} do
      # Test that special characters in policies are handled correctly in visual output
      diagram = Policy.for_resource(OptimizationTestResource)

      # This resource has a policy with special characters: "quotes" & <test>
      result = diagram |> Flowchart.compose() |> IO.iodata_to_binary()
      assert result =~ "special_chars"

      # Render to PNG
      assert png = AshDiagram.render(diagram, format: :png, background_color: "white")

      out_path = Path.join(tmp_dir, "special_characters.png")
      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "special_characters_diff.png")

      assert_alike(
        out_path,
        fixture_path("special_characters.png"),
        diff_path
      )
    end
  end
end
