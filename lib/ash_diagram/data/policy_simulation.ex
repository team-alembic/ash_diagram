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
  alias Ash.Policy.Check.ActorPresent
  alias Ash.Policy.Info
  alias Ash.Policy.Policy
  alias Ash.SatSolver
  alias AshDiagram.Data.Extension
  alias AshDiagram.Flowchart
  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style
  alias AshDiagram.Flowchart.Subgraph

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
  @type expansion_callback() :: (SatSolver.boolean_expr(Check.ref()) ->
                                   SatSolver.boolean_expr(Check.ref()))

  @type option() :: {:title, String.t()} | {:expansion_callback, expansion_callback()}

  @type options() :: [option()]

  @typep clauses() :: [integer()]
  @typep bindings() :: %{pos_integer() => Check.ref()}
  @typep processed_clauses() :: [{[Check.ref()], non_neg_integer()}]

  @doc """
  Creates a policy simulation flow chart diagram from explicit policies.
  """
  @spec for_policies(resource :: Ash.Resource.t(), policies :: [Policy.t()], options :: options()) ::
          Flowchart.t()
  def for_policies(resource, policies, options \\ [])
      when is_atom(resource) and is_list(policies) do
    options = Keyword.put_new(options, :expansion_callback, & &1)

    diagram =
      if Enum.empty?(policies) do
        create_no_policies_diagram(options)
      else
        create_simulation_diagram(policies, options)
      end

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
          action :: Ash.Resource.Actions.action(),
          options :: options()
        ) ::
          Flowchart.t()
  def for_action(resource, action, options \\ []) when is_atom(resource) and is_struct(action) do
    policies = Info.policies(resource)

    options = Keyword.put_new(options, :expansion_callback, & &1)

    action_expansion_callback = fn
      {ActionType, opts} -> action.type in List.wrap(opts[:type])
      {Action, opts} -> action.name in List.wrap(opts[:action])
      other -> options[:expansion_callback].(other)
    end

    options = Keyword.put(options, :expansion_callback, action_expansion_callback)

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
    field_name =
      case field do
        %{name: name} when is_atom(name) -> name
        name when is_atom(name) -> name
        _ -> raise ArgumentError, "field must be an atom or a struct with a name property"
      end

    field_policies = resource |> Info.field_policies_for_field(field_name) |> List.wrap()

    for_policies(resource, field_policies, options)
  end

  @spec create_no_policies_diagram(options()) :: Flowchart.t()
  defp create_no_policies_diagram(options) do
    entries = [
      %Node{id: "start", label: "Start", shape: :circle},
      %Node{id: "no_policies", label: "No policies defined", shape: :rectangle},
      %Node{id: "authorized", label: "Authorized", shape: :circle},
      %Edge{from: "start", to: "no_policies", type: :arrow},
      %Edge{from: "no_policies", to: "authorized", type: :arrow},
      create_result_styles()
    ]

    %Flowchart{
      title: options[:title],
      direction: :top_bottom,
      entries: List.flatten(entries)
    }
  end

  @spec create_simulation_diagram([Policy.t()], options()) :: Flowchart.t()
  defp create_simulation_diagram(policies, options) do
    {cnf, bindings} =
      policies
      |> Policy.expression()
      |> SatSolver.expand_expression(options[:expansion_callback])
      |> SatSolver.simplify_expression()
      |> SatSolver.expand_expression(&clean_access_type_options/1)
      |> SatSolver.simplify_expression()
      |> SatSolver.expand_expression(&split_action_checks/1)
      |> SatSolver.simplify_expression()
      |> SatSolver.expand_expression(&merge_and_conditions/1)
      |> SatSolver.simplify_expression()
      |> SatSolver.to_cnf()

    # Unbind the CNF to get actual check references
    {clauses, unbindings} = SatSolver.unbind(cnf, bindings)

    # Process clauses to create check references
    clauses = process_clauses(clauses, unbindings)

    # Create the diagram from processed clauses
    entries = create_cnf_diagram_entries(clauses, options)

    %Flowchart{
      title: options[:title],
      direction: :top_bottom,
      entries: List.flatten(entries)
    }
  end

  @spec flatten_or_list(SatSolver.boolean_expr(Check.ref())) :: [Check.ref()]
  defp flatten_or_list(value)
  defp flatten_or_list({:or, left, right}), do: flatten_or_list(left) ++ flatten_or_list(right)
  defp flatten_or_list(other), do: [other]

  @spec clean_access_type_options(SatSolver.boolean_expr(Check.ref())) ::
          SatSolver.boolean_expr(Check.ref())
  defp clean_access_type_options(expression)

  defp clean_access_type_options({module, opts}) when is_atom(module) and is_list(opts) do
    {module, Keyword.delete(opts, :access_type)}
  end

  defp clean_access_type_options(other), do: other

  @spec split_action_checks(SatSolver.boolean_expr(Check.ref())) ::
          SatSolver.boolean_expr(Check.ref())
  defp split_action_checks(expression)

  defp split_action_checks({ActionType, opts}) do
    opts[:type]
    |> List.wrap()
    |> Enum.map(fn type ->
      {ActionType, type: [type]}
    end)
    |> Enum.reduce(&{:or, &2, &1})
  end

  defp split_action_checks({Action, opts}) do
    opts[:action]
    |> List.wrap()
    |> Enum.map(fn action ->
      {Action, action: action}
    end)
    |> Enum.reduce(&{:or, &2, &1})
  end

  defp split_action_checks({Ash.Policy.Check.ActorAbsent, _opts}) do
    {:not, {ActorPresent, []}}
  end

  defp split_action_checks(other), do: other

  @spec merge_and_conditions(SatSolver.boolean_expr(Check.ref())) ::
          SatSolver.boolean_expr(Check.ref())
  defp merge_and_conditions(expression)

  defp merge_and_conditions({:and, {ActionType, left_opts}, {ActionType, right_opts}}) do
    case left_opts[:type] -- (left_opts[:type] -- right_opts[:type]) do
      [] -> false
      types -> {ActionType, type: types}
    end
  end

  defp merge_and_conditions({:and, {Action, left_opts}, {Action, right_opts}}) do
    case left_opts[:action] -- (left_opts[:action] -- right_opts[:action]) do
      [] -> false
      actions -> {Action, action: actions}
    end
  end

  defp merge_and_conditions(other), do: other

  @spec optimize_clause_expression(SatSolver.boolean_expr(Check.ref())) ::
          SatSolver.boolean_expr(Check.ref())
  defp optimize_clause_expression(expression)

  defp optimize_clause_expression({:or, {ActionType, left_opts}, {ActionType, right_opts}}) do
    {ActionType, type: Enum.uniq(left_opts[:type] ++ right_opts[:type])}
  end

  defp optimize_clause_expression({:or, {Action, left_opts}, {Action, right_opts}}) do
    {Action, action: Enum.uniq(left_opts[:action] ++ right_opts[:action])}
  end

  defp optimize_clause_expression({:not, {ActorPresent, _opts}}) do
    {ActorPresent, []}
  end

  defp optimize_clause_expression(other), do: other

  @spec process_clauses([clauses()], bindings()) :: processed_clauses()
  defp process_clauses(clauses, unbindings) do
    clauses
    |> Enum.flat_map(fn clause ->
      clause
      |> Enum.map(fn
        literal when literal < 0 ->
          {:not, Map.fetch!(unbindings, abs(literal))}

        literal ->
          Map.fetch!(unbindings, literal)
      end)
      |> Enum.uniq_by(&Policy.debug_expr/1)
      |> Enum.reduce(&{:or, &1, &2})
      |> SatSolver.simplify_expression()
      |> SatSolver.expand_expression(&optimize_clause_expression/1)
      |> SatSolver.simplify_expression()
      |> flatten_or_list()
      |> case do
        [true] -> []
        checks -> [checks]
      end
    end)
    |> Enum.with_index()
  end

  @spec create_cnf_diagram_entries(processed_clauses(), options()) :: [Flowchart.entry()]
  defp create_cnf_diagram_entries(clauses, options)

  defp create_cnf_diagram_entries([], _options) do
    [
      %Node{id: "start", label: "Start", shape: :circle},
      %Node{id: "always_true", label: "Always Authorized", shape: :rectangle},
      %Node{id: "authorized", label: "Authorized", shape: :circle},
      %Edge{from: "start", to: "always_true", type: :arrow},
      %Edge{from: "always_true", to: "authorized", type: :arrow},
      create_result_styles()
    ]
  end

  defp create_cnf_diagram_entries(clauses, options) do
    clause_entries = create_clause_entries(clauses, options)
    connections = create_clause_connections(clauses)

    [
      %Node{id: "start", label: "Start", shape: :circle},
      %Node{id: "authorized", label: "Authorized", shape: :circle},
      clause_entries,
      connections,
      create_result_styles(),
      create_simulation_styles()
    ]
  end

  @spec create_clause_entries(processed_clauses(), options()) :: [Flowchart.entry()]
  defp create_clause_entries(clauses, options)

  defp create_clause_entries([{checks, index}], _options) do
    create_single_clause_nodes(checks, ["clause_", to_string(index)])
  end

  defp create_clause_entries(multiple_clauses, _options) do
    Enum.map(multiple_clauses, fn
      {[check], index} ->
        create_single_clause_nodes([check], ["clause_", to_string(index)])

      {checks, index} ->
        %Subgraph{
          direction: :top_bottom,
          id: ["clause_", to_string(index)],
          label: quote_and_escape("Clause #{index + 1} (OR)"),
          entries: create_single_clause_nodes(checks, ["clause_", to_string(index)])
        }
    end)
  end

  @spec create_single_clause_nodes([Check.ref()], iodata()) :: [Node.t()]
  defp create_single_clause_nodes(checks, id_prefix)

  defp create_single_clause_nodes([single_check], id_prefix) do
    %Node{
      id: id_prefix,
      label: format_check_label(single_check),
      shape: :rhombus
    }
  end

  defp create_single_clause_nodes(multiple_checks, id_prefix) do
    multiple_checks
    |> Enum.with_index()
    |> Enum.map(fn {check, check_idx} ->
      %Node{
        id: [id_prefix, "_check_", to_string(check_idx)],
        label: format_check_label(check),
        shape: :rhombus
      }
    end)
  end

  @spec create_clause_connections(processed_clauses()) :: [Edge.t()]
  defp create_clause_connections(clauses) do
    # Generate the sequential flow: start -> clause_0 -> clause_1 -> ... -> authorized
    flow_nodes =
      ["start"] ++
        Enum.map(clauses, fn {_checks, index} -> "clause_#{index}" end) ++ ["authorized"]

    flow_nodes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] ->
      %Edge{from: from, to: to, type: :arrow}
    end)
  end

  @spec format_check_label(Check.ref()) :: String.t()
  defp format_check_label(check) do
    check
    |> Policy.debug_expr()
    |> String.replace_leading("Expr:\n\n", "")
    |> quote_and_escape()
  end

  @spec quote_and_escape(String.t()) :: String.t()
  defp quote_and_escape(text) when is_binary(text) do
    escaped =
      text
      |> String.replace("\"", "'")
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace("\n", " ")
      |> String.replace("\r", " ")

    "\"#{escaped}\""
  end

  @spec create_result_styles() :: [Style.t()]
  defp create_result_styles do
    [
      %Style{
        type: :class,
        name: "authorized",
        properties: %{"fill" => "#e8f5e8", "stroke" => "#4CAF50", "stroke-width" => "2px"}
      },
      %Style{type: :node, id: "authorized", classes: ["authorized"]}
    ]
  end

  @spec create_simulation_styles() :: [Style.t()]
  defp create_simulation_styles do
    [
      %Style{
        type: :class,
        name: "clause",
        properties: %{"fill" => "#f3e5f5", "stroke" => "#9C27B0", "stroke-width" => "2px"}
      },
      %Style{
        type: :class,
        name: "or_node",
        properties: %{"fill" => "#fff3e0", "stroke" => "#FF9800"}
      }
    ]
  end
end
