defmodule AshDiagram.ClarityContent.PolicySimulationTest do
  use ExUnit.Case, async: true

  alias Ash.Policy.Info, as: PolicyInfo
  alias Ash.Resource.Info
  alias AshDiagram.ClarityContent.PolicySimulation
  alias AshDiagram.Flow.User
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Calculation
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Policy
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Ash.Resource

  # Basic behavior tests
  test "name" do
    assert PolicySimulation.name() == "Policy Simulation"
  end

  test "description" do
    assert PolicySimulation.description() == "Interactive flowchart showing step-by-step policy authorization logic"
  end

  # Applies tests for supported vertex types
  test "applies to resource" do
    vertex = %Resource{resource: User}
    assert PolicySimulation.applies?(vertex, nil)
  end

  test "applies to action" do
    action = Enum.find(Info.actions(User), &(&1.name == :create))
    vertex = %Action{resource: User, action: action}
    assert PolicySimulation.applies?(vertex, nil)
  end

  test "applies to policy" do
    policy = Enum.find(PolicyInfo.policies(User), &(&1.condition != []))
    vertex = %Policy{resource: User, policy: policy}
    assert PolicySimulation.applies?(vertex, nil)
  end

  test "applies to attribute" do
    attribute = Enum.find(Info.attributes(User), &(&1.name == :first_name))
    vertex = %Attribute{resource: User, attribute: attribute}
    assert PolicySimulation.applies?(vertex, nil)
  end

  test "applies to relationship" do
    relationship = Enum.find(Info.relationships(User), &(&1.name == :org))
    vertex = %Relationship{resource: User, relationship: relationship}
    assert PolicySimulation.applies?(vertex, nil)
  end

  test "applies to calculation" do
    # User resource doesn't have calculations, so we create a mock one
    calculation = %{name: :full_name, type: :string}
    vertex = %Calculation{resource: User, calculation: calculation}
    assert PolicySimulation.applies?(vertex, nil)
  end

  test "applies to aggregate" do
    # User resource doesn't have aggregates, so we create a mock one
    aggregate = %{name: :count, kind: :count}
    vertex = %Aggregate{resource: User, aggregate: aggregate}
    assert PolicySimulation.applies?(vertex, nil)
  end

  # Negative applies tests
  test "does not apply to application" do
    vertex = %Vertex.Application{app: :ash_diagram, description: "", version: ""}
    refute PolicySimulation.applies?(vertex, nil)
  end

  test "does not apply to domain" do
    vertex = %Domain{domain: AshDiagram.Flow.Domain}
    refute PolicySimulation.applies?(vertex, nil)
  end

  test "does not apply to other vertex types" do
    refute PolicySimulation.applies?(%{}, nil)
  end

  # Render static tests for each vertex type
  test "generates mermaid content for resource" do
    vertex = %Resource{resource: User}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end

  test "generates mermaid content for action" do
    action = Enum.find(Info.actions(User), &(&1.name == :create))
    vertex = %Action{resource: User, action: action}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end

  test "generates mermaid content for policy" do
    policy = Enum.find(PolicyInfo.policies(User), &(&1.condition != []))
    vertex = %Policy{resource: User, policy: policy}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end

  test "generates mermaid content for attribute" do
    attribute = Enum.find(Info.attributes(User), &(&1.name == :first_name))
    vertex = %Attribute{resource: User, attribute: attribute}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end

  test "generates mermaid content for relationship" do
    relationship = Enum.find(Info.relationships(User), &(&1.name == :org))
    vertex = %Relationship{resource: User, relationship: relationship}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end

  test "generates mermaid content for calculation" do
    calculation = %{name: :full_name, type: :string}
    vertex = %Calculation{resource: User, calculation: calculation}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end

  test "generates mermaid content for aggregate" do
    aggregate = %{name: :count, kind: :count}
    vertex = %Aggregate{resource: User, aggregate: aggregate}
    assert {:mermaid, content} = PolicySimulation.render_static(vertex, nil)
    assert String.contains?(content, "flowchart TD")
    assert is_binary(content)
    assert String.length(content) > 0
  end
end
