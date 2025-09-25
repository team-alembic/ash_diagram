defmodule AshDiagram.Flow.MultipleConditionalPoliciesResource do
  @moduledoc """
  Resource with multiple conditional policies to test "at least one policy applies" logic.
  """
  use Ash.Resource,
    domain: AshDiagram.Flow.Domain,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer]

  resource do
    description "Resource for testing 'at least one policy applies' logic"
  end

  policies do
    # Policy 1: Only applies to admin users
    policy actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Policy 2: Only applies to manager users in same org
    policy expr(actor(:role) == :manager and relates_to_actor_via(:organization)) do
      authorize_if actor_present()
    end

    # Policy 3: Only applies to read actions
    policy action_type(:read) do
      authorize_if actor_present()
    end

    # Policy 4: Only applies to specific action
    policy action(:special_action) do
      authorize_if actor_attribute_equals(:approved, true)
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    action :special_action, :boolean do
      argument :data, :string
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :approved, :boolean, default: false
    attribute :role, :atom, constraints: [one_of: [:user, :manager, :admin]], default: :user
  end

  relationships do
    belongs_to :organization, AshDiagram.Flow.Org, public?: true
  end
end
