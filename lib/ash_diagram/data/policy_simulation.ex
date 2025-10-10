defmodule AshDiagram.Data.PolicySimulation do
  @moduledoc """
  Creates flowchart diagrams that show how Ash policies decide whether to authorize or deny access.

  The diagrams visualize policy logic as a step-by-step flow, showing all the checks
  that need to pass for authorization. Users can see the decision path from start to
  authorized result, with each policy condition displayed as a decision node.
  """

  alias Ash.Policy.Check
  alias Ash.Policy.Check.Action
  alias Ash.Policy.Check.ActionType
  alias Ash.Policy.Info
  alias Ash.Policy.Policy
  alias Ash.Resource.Actions
  alias AshDiagram.Data.Extension
  alias AshDiagram.Flowchart
  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style
  alias Crux.Expression
  alias Crux.Formula

  @typedoc """
  A function that transforms policy checks before they are included in the simulation diagram.

  This callback allows you to "prime" decisions by replacing specific checks with predetermined
  values (true/false) or simplified expressions. When a check is primed, the simulation will
  automatically discard any branches that become unreachable, creating a cleaner diagram
  focused on the remaining decision paths.

  ## Examples

      # Prime actor_present checks to always be true
      expansion_callback = fn
        {ActorPresent, _opts} -> true
        other -> other
      end

      # Prime specific action types
      expansion_callback = fn
        {ActionType, opts} -> :read in List.wrap(opts[:type])
        other -> other
      end

  """
  @type expansion_callback() :: (Expression.t(Check.ref()) ->
                                   Expression.t(Check.ref()))

  @type option() :: {:title, String.t()} | {:expansion_callback, expansion_callback()}

  @type options() :: [option()]

  @doc """
  Creates a policy simulation flow chart diagram from explicit policies.
  """
  @spec for_policies(resource :: Ash.Resource.t(), policies :: [Policy.t()], options :: options()) ::
          Flowchart.t()
  def for_policies(resource, policies, options \\ [])
      when is_atom(resource) and is_list(policies) do
    options = Keyword.put_new(options, :expansion_callback, & &1)

    diagram = create_simulation_diagram(resource, policies, options)

    resource_extensions = Ash.Resource.Info.extensions(resource)

    domain_extensions =
      resource
      |> Ash.Resource.Info.domain()
      |> Ash.Domain.Info.extensions()

    extensions = Enum.uniq(resource_extensions ++ domain_extensions)

    Extension.construct_diagram(__MODULE__, extensions, diagram)
  end

  @doc """
  Creates a policy simulation flow chart diagram for a single resource.
  """
  @spec for_resource(resource :: Ash.Resource.t(), options :: options()) :: Flowchart.t()
  def for_resource(resource, options \\ []) when is_atom(resource) do
    policies = Info.policies(resource)
    for_policies(resource, policies, options)
  end

  @doc """
  Creates a policy simulation flow chart diagram for a specific action.
  """
  @spec for_action(
          resource :: Ash.Resource.t(),
          action :: Actions.action(),
          options :: options()
        ) ::
          Flowchart.t()
  def for_action(resource, action, options \\ []) when is_atom(resource) and is_struct(action) do
    policies = Info.policies(resource)
    options = build_action_expansion_callback(action, options)
    for_policies(resource, policies, options)
  end

  @doc """
  Creates a policy simulation flow chart diagram for a specific field.
  """
  @spec for_field(
          resource :: Ash.Resource.t(),
          field ::
            atom()
            | Ash.Resource.Attribute.t()
            | Ash.Resource.Relationships.relationship()
            | Ash.Resource.Calculation.t()
            | Ash.Resource.Aggregate.t(),
          options :: options()
        ) :: Flowchart.t()
  def for_field(resource, field, options \\ []) when is_atom(resource) do
    field_name = extract_field_name(field)
    field_policies = resource |> Info.field_policies_for_field(field_name) |> List.wrap()
    for_policies(resource, field_policies, options)
  end

  @spec create_simulation_diagram(Ash.Resource.t(), [Policy.t()], options()) :: Flowchart.t()
  defp create_simulation_diagram(resource, policies, options) do
    decision_tree = build_decision_tree(resource, policies, options)
    entries = build_flowchart_entries(decision_tree)

    %Flowchart{
      title: options[:title],
      direction: :top_bottom,
      entries: List.flatten(entries)
    }
  end

  @spec build_decision_tree(Ash.Resource.t(), [Policy.t()], options()) :: Crux.tree(Check.ref())
  defp build_decision_tree(resource, policies, options) do
    check_context = %{resource: resource}
    scenario_options = Policy.scenario_options(check_context)

    policies
    |> Policy.expression(check_context)
    |> Expression.postwalk(options[:expansion_callback])
    |> Expression.postwalk(&clean_access_type_options/1)
    |> Expression.simplify()
    |> Formula.from_expression()
    |> Crux.decision_tree(scenario_options)
  end

  @spec build_flowchart_entries(Crux.tree(Check.ref())) :: [Flowchart.entry()]
  defp build_flowchart_entries(decision_tree) do
    case decision_tree do
      false -> forbidden_only_entries()
      tree -> decision_tree_entries(tree)
    end
  end

  @spec decision_tree_entries(Crux.tree(Check.ref())) :: [Flowchart.entry()]
  defp decision_tree_entries(tree) do
    {nodes, edges, _cache} = traverse_decision_tree(tree, "start", [], %{})

    List.flatten([
      base_nodes(),
      nodes,
      edges,
      create_styles()
    ])
  end

  @spec forbidden_only_entries() :: [Flowchart.entry()]
  defp forbidden_only_entries do
    [
      %Node{id: "start", label: "Start", shape: :circle},
      %Node{id: "forbidden", label: "Forbidden", shape: :circle},
      %Edge{from: "start", to: "forbidden", type: :arrow},
      create_styles()
    ]
  end

  @spec base_nodes() :: [Node.t()]
  defp base_nodes do
    [
      %Node{id: "start", label: "Start", shape: :circle},
      %Node{id: "authorized", label: "Authorized", shape: :circle}
    ]
  end

  @spec traverse_decision_tree(Crux.tree(Check.ref()), iodata(), iodata(), map()) ::
          {[Node.t()], [Edge.t()], map()}
  defp traverse_decision_tree(tree, from_id, path, cache)

  defp traverse_decision_tree(true, from_id, _path, cache) do
    edge = %Edge{from: from_id, to: "authorized", type: :arrow}
    {[], [edge], cache}
  end

  defp traverse_decision_tree(false, _from_id, _path, cache) do
    {[], [], cache}
  end

  defp traverse_decision_tree({check, false_branch, true_branch} = tree, from_id, path, cache) do
    # Check if we've already processed this exact tree
    case Map.get(cache, tree) do
      nil ->
        # First time seeing this tree - process it
        check_id = ["check_", path]

        check_node = %Node{
          id: check_id,
          label: format_check_label(check),
          shape: :rhombus
        }

        # Connect from current node to check node
        to_check_edge = %Edge{from: from_id, to: check_id, type: :arrow}

        # Cache this tree with its check_id
        updated_cache = Map.put(cache, tree, check_id)

        # Traverse false branch (left)
        {false_nodes, false_edges, cache_after_false} =
          traverse_decision_tree(false_branch, check_id, [path, "l"], updated_cache)

        # Traverse true branch (right)
        {true_nodes, true_edges, final_cache} =
          traverse_decision_tree(true_branch, check_id, [path, "r"], cache_after_false)

        # Create labeled edges and filter out direct edges
        {false_edge, true_edge} = create_labeled_edges(check_id, false_edges, true_edges)
        filtered_edges = filter_direct_edges(false_edges, true_edges, check_id)

        nodes = [check_node | false_nodes ++ true_nodes]
        edges = [to_check_edge, false_edge, true_edge | filtered_edges]

        {nodes, Enum.reject(edges, &is_nil/1), final_cache}

      existing_check_id ->
        # We've seen this tree before - just create an edge to the existing node
        edge = %Edge{from: from_id, to: existing_check_id, type: :arrow}
        {[], [edge], cache}
    end
  end

  @spec build_action_expansion_callback(Actions.action(), options()) :: options()
  defp build_action_expansion_callback(action, options) do
    options = Keyword.put_new(options, :expansion_callback, & &1)

    action_expansion_callback = fn
      {ActionType, opts} -> action.type in List.wrap(opts[:type])
      {Action, opts} -> action.name in List.wrap(opts[:action])
      other -> options[:expansion_callback].(other)
    end

    Keyword.put(options, :expansion_callback, action_expansion_callback)
  end

  @spec extract_field_name(atom() | map()) :: atom()
  defp extract_field_name(field) do
    case field do
      %{name: name} when is_atom(name) -> name
      name when is_atom(name) -> name
      _ -> raise ArgumentError, "field must be an atom or a struct with a name property"
    end
  end

  @spec create_labeled_edges(iodata(), [Edge.t()], [Edge.t()]) :: {Edge.t() | nil, Edge.t() | nil}
  defp create_labeled_edges(check_id, false_edges, true_edges) do
    false_edge =
      case false_edges do
        [%Edge{from: ^check_id, to: to} | _] ->
          %Edge{from: check_id, to: to, type: :arrow, label: "No"}

        _ ->
          nil
      end

    true_edge =
      case true_edges do
        [%Edge{from: ^check_id, to: to} | _] ->
          %Edge{from: check_id, to: to, type: :arrow, label: "Yes"}

        _ ->
          nil
      end

    {false_edge, true_edge}
  end

  @spec filter_direct_edges([Edge.t()], [Edge.t()], iodata()) :: [Edge.t()]
  defp filter_direct_edges(false_edges, true_edges, check_id) do
    false_edges_filtered = Enum.reject(false_edges, &(&1.from == check_id))
    true_edges_filtered = Enum.reject(true_edges, &(&1.from == check_id))
    false_edges_filtered ++ true_edges_filtered
  end

  @spec clean_access_type_options(Expression.t(Check.ref())) ::
          Expression.t(Check.ref())
  defp clean_access_type_options(expression)

  defp clean_access_type_options({module, opts}) when is_atom(module) and is_list(opts) do
    {module, Keyword.delete(opts, :access_type)}
  end

  defp clean_access_type_options(other), do: other

  @spec format_check_label(Check.ref()) :: String.t()
  defp format_check_label(check) do
    check
    |> Expression.to_string(fn
      {check_module, check_opts} -> check_module.describe(check_opts)
      v -> Macro.to_string(v)
    end)
    |> escape()
  end

  @spec escape(String.t()) :: String.t()
  defp escape(text) when is_binary(text) do
    text
    |> String.replace(~r/["&<>\r\n]/, fn
      "\"" -> "'"
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      char when char in ["\n", "\r"] -> " "
    end)
    |> then(&"\"#{&1}\"")
  end

  @spec create_styles() :: [Style.t()]
  defp create_styles do
    [
      %Style{type: :node, id: "authorized", classes: ["authorized"]},
      %Style{type: :node, id: "forbidden", classes: ["forbidden"]},
      %Style{
        type: :class,
        name: "authorized",
        properties: %{"fill" => "#e8f5e8", "stroke" => "#4CAF50", "stroke-width" => "2px"}
      },
      %Style{
        type: :class,
        name: "forbidden",
        properties: %{"fill" => "#ffebee", "stroke" => "#f44336", "stroke-width" => "2px"}
      }
    ]
  end
end
