defmodule AshDiagram.Data.Policy do
  @moduledoc """
  Provides functions to create Policy Flow Chart diagrams for Ash applications.

  This module generates Mermaid flowcharts that visualize policy authorization logic
  for Ash resources, showing the flow of conditions, checks, and final authorization decisions.
  """

  alias Ash.Policy.Check.Static
  alias Ash.Policy.Info
  alias Ash.Policy.Policy
  alias AshDiagram.Data.Extension
  alias AshDiagram.Flowchart
  alias AshDiagram.Flowchart.Edge
  alias AshDiagram.Flowchart.Node
  alias AshDiagram.Flowchart.Style
  alias AshDiagram.Flowchart.Subgraph

  defmodule CheckDestinationContext do
    @moduledoc false
    defstruct [
      :check,
      :policy,
      :check_index,
      :check_count,
      :last_policy?,
      :next_policy,
      :next_check,
      :next_policy_or_authorized,
      :next_check_or_forbidden,
      :next_check_or_next_policy
    ]

    @type t :: %__MODULE__{
            check: term(),
            policy: Policy.t(),
            check_index: non_neg_integer(),
            check_count: non_neg_integer(),
            last_policy?: boolean(),
            next_policy: String.t(),
            next_check: String.t(),
            next_policy_or_authorized: String.t(),
            next_check_or_forbidden: String.t(),
            next_check_or_next_policy: String.t()
          }
  end

  @type option() :: {:title, String.t()} | {:simplify?, boolean()}
  @type options() :: [option()]

  @default_options [
    title: nil,
    simplify?: true
  ]

  @doc """
  Creates a policy flow chart diagram for a single resource.
  """
  @spec for_resource(resource :: module(), options :: options()) :: Flowchart.t()
  def for_resource(resource, options \\ []) when is_atom(resource) do
    options = Keyword.merge(@default_options, options)

    policies = Info.policies(resource)

    diagram =
      if Enum.empty?(policies) do
        create_no_policies_diagram(resource, options)
      else
        create_policies_diagram(resource, policies, options)
      end

    resource_extensions = Ash.Resource.Info.extensions(resource)

    domain_extensions =
      resource
      |> Ash.Resource.Info.domain()
      |> Ash.Domain.Info.extensions()

    extensions = Enum.uniq(resource_extensions ++ domain_extensions)

    Extension.construct_diagram(__MODULE__, extensions, diagram)
  end

  @spec create_no_policies_diagram(module(), keyword()) :: Flowchart.t()
  defp create_no_policies_diagram(resource, options) do
    title =
      options[:title] ||
        IO.iodata_to_binary(["Policy Flow: ", inspect(resource), " (No Policies)"])

    entries = [
      %Node{id: "start", label: "Start", shape: :circle},
      %Node{id: "no_policies", label: "No policies defined", shape: :rectangle},
      %Node{id: "authorized", label: "Authorized", shape: :circle},
      %Edge{from: "start", to: "no_policies", type: :arrow},
      %Edge{from: "no_policies", to: "authorized", type: :arrow},
      create_result_styles()
    ]

    create_diagram(title, List.flatten(entries))
  end

  @spec create_policies_diagram(module(), [Policy.t()], keyword()) :: Flowchart.t()
  defp create_policies_diagram(resource, policies, options) do
    title = options[:title] || IO.iodata_to_binary(["Policy Flow: ", inspect(resource)])

    entries = [
      create_start_node(),
      create_at_least_one_policy_logic(policies),
      create_policy_check_nodes(policies),
      create_result_nodes(),
      create_policy_edges(policies),
      create_at_least_one_policy_edges(policies),
      create_result_styles()
    ]

    diagram = create_diagram(title, List.flatten(entries))

    if options[:simplify?] do
      simplify_diagram(diagram)
    else
      diagram
    end
  end

  @spec create_start_node() :: Node.t()
  defp create_start_node, do: %Node{id: "start", label: "Policy Evaluation Start", shape: :circle}

  @spec get_conditional_policies([Policy.t()]) :: [Policy.t()]
  defp get_conditional_policies(policies), do: Enum.filter(policies, &has_non_static_conditions/1)

  @spec has_non_static_conditions(Policy.t()) :: boolean()
  defp has_non_static_conditions(policy) do
    conditions = List.wrap(policy.condition || [])
    # Filter out static true conditions
    non_static_conditions = Enum.reject(conditions, &static_true_condition?/1)

    non_static_conditions != []
  end

  @spec static_true_condition?(term()) :: boolean()
  defp static_true_condition?(condition) do
    case condition do
      %{check_module: Static, check_opts: opts} -> opts[:result] == true
      {Static, opts} -> opts[:result] == true
      _ -> false
    end
  end

  @spec create_at_least_one_policy_logic([Policy.t()]) :: [Node.t() | Subgraph.t()]
  defp create_at_least_one_policy_logic(policies) do
    conditional_policies = get_conditional_policies(policies)

    if length(conditional_policies) > 1 do
      # Create "at least one policy applies" logic
      policy_condition_descriptions = get_policy_condition_descriptions(conditional_policies)

      if Enum.empty?(policy_condition_descriptions) do
        []
      else
        combined_description = Enum.join(policy_condition_descriptions, "\nor ")

        [
          %Subgraph{
            id: "at_least_one_policy",
            label: "at least one policy applies",
            entries: [
              %Node{
                id: "at_least_one_policy_check",
                label: quote_and_escape(combined_description),
                shape: :rhombus
              }
            ]
          }
        ]
      end
    else
      []
    end
  end

  @spec get_policy_condition_descriptions([Policy.t()]) :: [String.t()]
  defp get_policy_condition_descriptions(conditional_policies) do
    conditional_policies
    |> Enum.map(&format_policy_condition/1)
    |> Enum.filter(& &1)
  end

  @spec format_policy_condition(Policy.t()) :: String.t() | nil
  defp format_policy_condition(policy) do
    conditions = List.wrap(policy.condition || [])

    case describe_policy_conditions(conditions) do
      description when byte_size(description) > 0 ->
        if String.contains?(description, " and ") do
          [?(, description, ?)]
        else
          description
        end

      _ ->
        nil
    end
  end

  @spec create_at_least_one_policy_edges([Policy.t()]) :: [Edge.t()]
  defp create_at_least_one_policy_edges(policies) do
    conditional_policies = get_conditional_policies(policies)

    if length(conditional_policies) > 1 do
      [
        %Edge{from: "start", to: "at_least_one_policy_check", type: :arrow},
        %Edge{from: "at_least_one_policy_check", to: "forbidden", type: :arrow, label: "False"},
        %Edge{from: "at_least_one_policy_check", to: "0_conditions", type: :arrow, label: "True"}
      ]
    else
      []
    end
  end

  @spec describe_policy_conditions(list()) :: String.t()
  defp describe_policy_conditions(conditions) do
    conditions
    |> Enum.reject(fn condition ->
      # Filter out static true conditions
      case condition do
        %{check_module: Static, check_opts: opts} -> opts[:result] == true
        {Static, opts} -> opts[:result] == true
        _ -> false
      end
    end)
    |> Enum.map(&describe_condition_without_quotes/1)
    |> Enum.intersperse(" and ")
    |> Enum.join()
  end

  @spec describe_condition_without_quotes(term()) :: String.t()
  defp describe_condition_without_quotes(condition) do
    {mod, opts} =
      case condition do
        %{module: module, opts: opts} -> {module, opts}
        %{check_module: module, check_opts: opts} -> {module, opts}
        {module, opts} -> {module, opts}
      end

    if function_exported?(mod, :describe, 1) do
      mod.describe(opts)
    else
      inspect({mod, opts})
    end
  end

  @spec create_result_nodes() :: [Subgraph.t()]
  defp create_result_nodes do
    [
      %Subgraph{
        id: "results",
        label: "Results",
        entries: [
          %Node{id: "authorized", label: "Authorized", shape: :circle},
          %Node{id: "forbidden", label: "Forbidden", shape: :circle}
        ]
      }
    ]
  end

  @spec create_policy_check_nodes([Policy.t()]) :: [Subgraph.t() | Node.t()]
  defp create_policy_check_nodes(policies) do
    policies
    |> Enum.with_index()
    |> Enum.flat_map(fn {policy, policy_index} ->
      [
        create_policy_subgraph(policy, policy_index),
        create_condition_nodes(policy, policy_index),
        create_check_nodes(policy, policy_index)
      ]
    end)
  end

  @spec create_policy_subgraph(Policy.t(), non_neg_integer()) :: Subgraph.t()
  defp create_policy_subgraph(policy, policy_index) do
    description = get_policy_description(policy, policy_index)

    %Subgraph{
      id: IO.iodata_to_binary(["policy_", Integer.to_string(policy_index)]),
      label: description,
      entries: []
    }
  end

  @spec create_condition_nodes(Policy.t(), non_neg_integer()) :: Node.t()
  defp create_condition_nodes(policy, policy_index) do
    conditions = List.wrap(policy.condition || [])

    case conditions do
      [] ->
        %Node{
          id: IO.iodata_to_binary([Integer.to_string(policy_index), "_conditions"]),
          label: "always true",
          shape: :rhombus
        }

      _ ->
        condition_text = describe_conditions(conditions)

        %Node{
          id: IO.iodata_to_binary([Integer.to_string(policy_index), "_conditions"]),
          label: condition_text,
          shape: :rhombus
        }
    end
  end

  @spec create_check_nodes(Policy.t(), non_neg_integer()) :: [Node.t()]
  defp create_check_nodes(policy, policy_index) do
    policy.policies
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.map(fn {check, check_index} ->
      description = describe_check(check)

      %Node{
        id:
          IO.iodata_to_binary([
            Integer.to_string(policy_index),
            "_checks_",
            Integer.to_string(check_index)
          ]),
        label: description,
        shape: :rhombus
      }
    end)
  end

  @spec create_policy_edges([Policy.t()]) :: [Edge.t()]
  defp create_policy_edges(policies) do
    policy_count = Enum.count(policies)

    # Only create direct start edge if we don't have "at least one policy" logic
    conditional_policies = get_conditional_policies(policies)

    start_edge =
      if length(conditional_policies) > 1 do
        # "at least one policy" logic will handle the start edge
        []
      else
        [%Edge{from: "start", to: "0_conditions", type: :arrow}]
      end

    policy_edges =
      policies
      |> Enum.with_index()
      |> Enum.flat_map(fn {policy, policy_index} ->
        create_policy_flow_edges(policy, policy_index, policy_count)
      end)

    start_edge ++ policy_edges
  end

  @spec create_policy_flow_edges(Policy.t(), non_neg_integer(), non_neg_integer()) :: [Edge.t()]
  defp create_policy_flow_edges(policy, policy_index, policy_count) do
    checks = List.wrap(policy.policies || [])
    check_count = Enum.count(checks)
    last_policy? = policy_index == policy_count - 1
    next_policy = IO.iodata_to_binary([Integer.to_string(policy_index + 1), "_conditions"])

    # Condition to first check edge
    condition_edges = [
      %Edge{
        from: [Integer.to_string(policy_index), "_conditions"],
        to: [Integer.to_string(policy_index), "_checks_0"],
        type: :arrow,
        label: "True"
      },
      %Edge{
        from: [Integer.to_string(policy_index), "_conditions"],
        to: if(last_policy?, do: "authorized", else: next_policy),
        type: :arrow,
        label: "False"
      }
    ]

    # Check flow edges
    check_edges =
      checks
      |> Enum.with_index()
      |> Enum.flat_map(fn {check, check_index} ->
        create_check_flow_edges(
          check,
          policy,
          policy_index,
          check_index,
          check_count,
          last_policy?,
          next_policy
        )
      end)

    condition_edges ++ check_edges
  end

  @spec create_check_flow_edges(
          term(),
          Policy.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          boolean(),
          String.t()
        ) :: [Edge.t()]
  defp create_check_flow_edges(
         check,
         policy,
         policy_index,
         check_index,
         check_count,
         last_policy?,
         next_policy
       ) do
    current_check =
      [
        Integer.to_string(policy_index),
        "_checks_",
        Integer.to_string(check_index)
      ]

    next_check =
      IO.iodata_to_binary([
        Integer.to_string(policy_index),
        "_checks_",
        Integer.to_string(check_index + 1)
      ])

    next_policy_or_authorized = if last_policy?, do: "authorized", else: next_policy
    next_check_or_forbidden = if check_index == check_count - 1, do: "forbidden", else: next_check

    next_check_or_next_policy =
      if check_index == check_count - 1 && !last_policy?, do: next_policy, else: next_check

    context = %CheckDestinationContext{
      check: check,
      policy: policy,
      check_index: check_index,
      check_count: check_count,
      last_policy?: last_policy?,
      next_policy: next_policy,
      next_check: next_check,
      next_policy_or_authorized: next_policy_or_authorized,
      next_check_or_forbidden: next_check_or_forbidden,
      next_check_or_next_policy: next_check_or_next_policy
    }

    {true_dest, false_dest} = get_check_destinations(context)

    edges = [
      %Edge{from: current_check, to: true_dest, type: :arrow, label: "True"}
    ]

    if false_dest do
      edges ++ [%Edge{from: current_check, to: false_dest, type: :arrow, label: "False"}]
    else
      edges
    end
  end

  @spec create_result_styles() :: [Style.t()]
  defp create_result_styles do
    [
      %Style{
        type: :class,
        name: "authorized",
        properties: %{"fill" => "#e8f5e8", "stroke" => "#4CAF50", "stroke-width" => "2px"}
      },
      %Style{
        type: :class,
        name: "forbidden",
        properties: %{"fill" => "#ffebee", "stroke" => "#f44336", "stroke-width" => "2px"}
      },
      %Style{
        type: :class,
        name: "condition",
        properties: %{"fill" => "#e3f2fd", "stroke" => "#2196F3"}
      },
      %Style{type: :node, id: "authorized", classes: ["authorized"]},
      %Style{type: :node, id: "forbidden", classes: ["forbidden"]},
      %Style{type: :node, id: "start", classes: ["condition"]}
    ]
  end

  @spec create_diagram(String.t(), list()) :: Flowchart.t()
  defp create_diagram(title, entries) do
    extensions = []

    Extension.construct_diagram(__MODULE__, extensions, %Flowchart{
      title: title,
      direction: :top_bottom,
      entries: entries
    })
  end

  @spec describe_conditions(list()) :: String.t()
  defp describe_conditions(conditions) do
    conditions
    |> Enum.map(&describe_condition/1)
    |> Enum.intersperse(" and ")
    |> Enum.join()
  end

  @spec describe_condition(term()) :: String.t()
  defp describe_condition(condition) do
    {mod, opts} =
      case condition do
        %{module: module, opts: opts} -> {module, opts}
        %{check_module: module, check_opts: opts} -> {module, opts}
        {module, opts} -> {module, opts}
      end

    description =
      if function_exported?(mod, :describe, 1) do
        mod.describe(opts)
      else
        inspect({mod, opts})
      end

    quote_and_escape(description)
  end

  @spec describe_check(term()) :: String.t()
  defp describe_check(check) do
    description =
      if function_exported?(check.check_module, :describe, 1) do
        check.check_module.describe(check.check_opts)
      else
        IO.iodata_to_binary([Atom.to_string(check.type), ": ", inspect(check.check_module)])
      end

    quote_and_escape(description)
  end

  @spec quote_and_escape(binary()) :: String.t()
  defp quote_and_escape(text) when is_binary(text) do
    IO.iodata_to_binary([?\", escape(text), ?\"])
  end

  @spec quote_and_escape(term()) :: String.t()
  defp quote_and_escape(text) do
    text
    |> to_string()
    |> quote_and_escape()
  end

  @spec escape(binary()) :: String.t()
  defp escape(string) when is_binary(string) do
    escape_mermaid_text(string, :node)
  end

  # Helper function to check string containment for both binary and iodata
  @spec string_contains?(iodata() | nil, binary()) :: boolean()
  defp string_contains?(nil, _substring), do: false

  defp string_contains?(data, substring) when is_binary(data) do
    String.contains?(data, substring)
  end

  defp string_contains?(data, substring) when is_list(data) do
    data
    |> IO.iodata_to_binary()
    |> String.contains?(substring)
  end

  @spec get_policy_description(Policy.t(), non_neg_integer()) :: String.t()
  defp get_policy_description(policy, policy_index) do
    if policy.description && policy.description != "" do
      escaped_description = escape_mermaid_text(policy.description, :subgraph)

      IO.iodata_to_binary([
        "Policy ",
        Integer.to_string(policy_index + 1),
        ": ",
        escaped_description
      ])
    else
      IO.iodata_to_binary(["Policy ", Integer.to_string(policy_index + 1)])
    end
  end

  @spec escape_mermaid_text(String.t(), :node | :subgraph) :: String.t()
  defp escape_mermaid_text(text, :node) do
    text
    |> String.replace("\"", "'")
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\n", " ")
    |> String.replace("\r", " ")
  end

  defp escape_mermaid_text(text, :subgraph) do
    text
    |> String.replace("\"", "#quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("&", "&amp;")
  end

  @spec simplify_diagram(Flowchart.t()) :: Flowchart.t()
  defp simplify_diagram(diagram) do
    # Apply optimization pipeline similar to Ash's original implementation
    diagram
    |> remove_always_links()
    |> collapse_constant_nodes()
    |> remove_empty_subgraphs()
  end

  @spec remove_always_links(Flowchart.t(), non_neg_integer()) :: Flowchart.t()
  defp remove_always_links(diagram, max_iterations \\ 100)
  defp remove_always_links(diagram, 0), do: diagram

  defp remove_always_links(%Flowchart{entries: entries} = diagram, max_iterations) do
    # Find nodes with "always true" or "always false" labels
    always_nodes =
      Enum.filter(entries, fn entry ->
        match?(%Node{}, entry) and
          (string_contains?(entry.label || "", "always true") or
             string_contains?(entry.label || "", "always false"))
      end)

    if Enum.empty?(always_nodes) do
      diagram
    else
      # For each always node, find its target branch and redirect incoming links
      optimized_entries = optimize_always_nodes(entries, always_nodes)

      # Only recurse if changes were made
      if optimized_entries == entries do
        diagram
      else
        remove_always_links(%{diagram | entries: optimized_entries}, max_iterations - 1)
      end
    end
  end

  @spec optimize_always_nodes(list(), [Node.t()]) :: list()
  defp optimize_always_nodes(entries, always_nodes) do
    Enum.reduce(always_nodes, entries, fn always_node, acc_entries ->
      target_branch =
        if string_contains?(always_node.label || "", "always true"), do: "True", else: "False"

      # Find where this always_node leads when taking the target branch
      target_destination = find_edge_destination(acc_entries, always_node.id, target_branch)

      if target_destination do
        # Redirect all incoming edges to go directly to the target destination
        acc_entries
        |> redirect_edges_through_node(always_node.id, target_destination)
        |> remove_node_and_outgoing_edges(always_node.id)
      else
        acc_entries
      end
    end)
  end

  @spec collapse_constant_nodes(Flowchart.t(), non_neg_integer()) ::
          Flowchart.t()
  defp collapse_constant_nodes(diagram, max_iterations \\ 100)
  defp collapse_constant_nodes(diagram, 0), do: diagram

  defp collapse_constant_nodes(%Flowchart{entries: entries} = diagram, max_iterations) do
    # Find nodes where True and False edges lead to same destination
    nodes_to_collapse = find_constant_nodes(entries)

    if Enum.empty?(nodes_to_collapse) do
      diagram
    else
      # Collapse the first constant node found and recurse
      {node_id, destination, label} = hd(nodes_to_collapse)
      optimized_entries = collapse_node(entries, node_id, destination, label)

      # Only recurse if changes were made
      if optimized_entries == entries do
        diagram
      else
        collapse_constant_nodes(%{diagram | entries: optimized_entries}, max_iterations - 1)
      end
    end
  end

  @spec find_constant_nodes(list()) :: [{String.t(), String.t(), String.t()}]
  defp find_constant_nodes(entries) do
    entries
    # Filter for decision nodes (Node structs with rhombus shape)
    |> Enum.filter(fn entry -> match?(%Node{shape: :rhombus}, entry) end)
    |> Enum.flat_map(&get_constant_node_info(entries, &1))
  end

  @spec get_constant_node_info(list(), Node.t()) :: [{String.t(), String.t(), String.t()}]
  defp get_constant_node_info(entries, node) do
    true_dest = find_edge_destination(entries, node.id, "True")
    false_dest = find_edge_destination(entries, node.id, "False")

    if true_dest && false_dest && true_dest == false_dest do
      # Determine appropriate label for the collapsed edge
      label = if true_dest in ["authorized", "forbidden"], do: "", else: "Or"
      [{node.id, true_dest, label}]
    else
      []
    end
  end

  @spec collapse_node(list(), String.t(), String.t(), String.t()) :: list()
  defp collapse_node(entries, node_id, destination, edge_label) do
    entries
    |> remove_edges_from_node(node_id)
    |> remove_node_by_id(node_id)
    |> add_direct_edges_to_node(node_id, destination, edge_label)
  end

  @spec remove_empty_subgraphs(Flowchart.t()) :: Flowchart.t()
  defp remove_empty_subgraphs(%Flowchart{entries: entries} = diagram) do
    optimized_entries =
      Enum.reject(entries, fn entry ->
        case entry do
          %Subgraph{entries: subgraph_entries} ->
            # Remove if subgraph has no nodes (only edges are okay)
            Enum.all?(subgraph_entries, &match?(%Edge{}, &1))

          _ ->
            false
        end
      end)

    %{diagram | entries: optimized_entries}
  end

  # Helper functions for optimization

  @spec find_edge_destination(list(), String.t(), String.t()) :: String.t() | nil
  defp find_edge_destination(entries, from_node_id, label) do
    entries
    |> Enum.find(fn entry ->
      case entry do
        %Edge{from: ^from_node_id, label: ^label} -> true
        _ -> false
      end
    end)
    |> case do
      %Edge{to: destination} -> destination
      _ -> nil
    end
  end

  @spec redirect_edges_through_node(list(), String.t(), String.t()) :: list()
  defp redirect_edges_through_node(entries, through_node_id, new_destination) do
    Enum.map(entries, fn entry ->
      case entry do
        %Edge{to: ^through_node_id} = edge ->
          %{edge | to: new_destination}

        _ ->
          entry
      end
    end)
  end

  @spec remove_node_and_outgoing_edges(list(), String.t()) :: list()
  defp remove_node_and_outgoing_edges(entries, node_id) do
    Enum.reject(entries, fn entry ->
      case entry do
        %Node{id: ^node_id} -> true
        %Edge{from: ^node_id} -> true
        _ -> false
      end
    end)
  end

  @spec remove_edges_from_node(list(), String.t()) :: list()
  defp remove_edges_from_node(entries, node_id) do
    Enum.reject(entries, fn entry ->
      case entry do
        %Edge{from: ^node_id} -> true
        _ -> false
      end
    end)
  end

  @spec remove_node_by_id(list(), String.t()) :: list()
  defp remove_node_by_id(entries, node_id) do
    Enum.reject(entries, fn entry ->
      case entry do
        %Node{id: ^node_id} -> true
        _ -> false
      end
    end)
  end

  @spec add_direct_edges_to_node(list(), String.t(), String.t(), String.t()) :: list()
  defp add_direct_edges_to_node(entries, old_node_id, destination, edge_label) do
    # Find all edges that pointed to the old node and redirect them to destination
    incoming_edges =
      Enum.filter(entries, fn entry ->
        case entry do
          %Edge{to: ^old_node_id} -> true
          _ -> false
        end
      end)

    # Create new direct edges
    new_edges =
      Enum.map(incoming_edges, fn edge ->
        %Edge{
          from: edge.from,
          to: destination,
          type: edge.type,
          label: if(edge_label == "", do: nil, else: edge_label)
        }
      end)

    # Remove old edges and add new ones
    entries
    |> Enum.reject(fn entry ->
      case entry do
        %Edge{to: ^old_node_id} -> true
        _ -> false
      end
    end)
    |> Enum.concat(new_edges)
  end

  @spec get_check_destinations(CheckDestinationContext.t()) :: {String.t(), String.t() | nil}
  defp get_check_destinations(context) do
    case context.check.type do
      :authorize_if -> handle_authorize_if(context)
      :forbid_if -> handle_forbid_if(context)
      :authorize_unless -> handle_authorize_unless(context)
      :forbid_unless -> handle_forbid_unless(context)
    end
  end

  @spec handle_authorize_if(CheckDestinationContext.t()) :: {String.t(), String.t()}
  defp handle_authorize_if(context) do
    if context.policy.bypass? do
      {"authorized", context.next_policy_or_authorized}
    else
      {context.next_policy_or_authorized, context.next_check_or_forbidden}
    end
  end

  @spec handle_forbid_if(CheckDestinationContext.t()) :: {String.t(), String.t() | nil}
  defp handle_forbid_if(context) do
    forbidden_dest =
      if context.policy.bypass?, do: context.next_policy_or_authorized, else: "forbidden"

    false_dest =
      if context.check_index == context.check_count - 1 && !context.last_policy?,
        do: context.next_policy,
        else: context.next_check

    {forbidden_dest,
     if(context.check_index == context.check_count - 1, do: nil, else: false_dest)}
  end

  @spec handle_authorize_unless(CheckDestinationContext.t()) :: {String.t(), String.t()}
  defp handle_authorize_unless(context) do
    if context.policy.bypass? do
      {"authorized", context.next_policy_or_authorized}
    else
      {context.next_check_or_forbidden, context.next_policy_or_authorized}
    end
  end

  @spec handle_forbid_unless(CheckDestinationContext.t()) :: {String.t() | nil, String.t()}
  defp handle_forbid_unless(context) do
    forbidden_dest =
      if context.policy.bypass?, do: context.next_policy_or_authorized, else: "forbidden"

    true_dest =
      if(context.check_index == context.check_count - 1,
        do: nil,
        else: context.next_check_or_next_policy
      )

    {true_dest, forbidden_dest}
  end
end
