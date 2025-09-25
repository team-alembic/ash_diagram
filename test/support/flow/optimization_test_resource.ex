defmodule AshDiagram.Flow.OptimizationTestResource do
  @moduledoc """
  Resource designed specifically to test policy chart optimization features.
  Contains edge cases that should trigger various optimization behaviors.
  """
  use Ash.Resource,
    domain: AshDiagram.Flow.Domain,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer]

  resource do
    description "Resource for testing policy optimizations"
  end

  policies do
    # Policy with always() condition - should be optimized away
    policy action(:read_always) do
      authorize_if always()
    end

    # Policy where both True and False lead to same destination - should be collapsed
    policy action(:collapse_test) do
      authorize_if actor_attribute_equals(:role, :admin)
      forbid_if actor_attribute_equals(:role, :admin)
    end

    # Policy with static true check - should be simplified
    policy action_type(:read) do
      authorize_if actor_present()
    end

    # Policy with static false check - should be simplified
    policy action_type(:create) do
      forbid_if always()
      authorize_if actor_present()
    end

    # Policy with special characters in description - tests escaping
    policy action(:special_chars) do
      description "Policy with \"quotes\" & special chars <test>"
      authorize_if actor_present()
    end

    # Policy that could be optimized
    policy action_type(:update) do
      authorize_if always()
    end

    # Multiple bypass policies - tests bypass handling
    bypass actor_attribute_equals(:role, :super_admin) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :system) do
      authorize_if always()
    end

    # Complex conditions with "and" logic
    policy action_type(:destroy) do
      authorize_if expr(
                     actor(:role) == :manager and
                       actor(:approved) == true and
                       relates_to_actor_via(:organization)
                   )
    end

    # Redundant always links scenario
    policy action(:redundant_links) do
      authorize_if always()
      forbid_if always()
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    action :read_always, :boolean
    action :collapse_test, :boolean

    action :special_chars, :boolean do
      argument :test, :string
    end

    action :redundant_links, :boolean
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :approved, :boolean, default: false

    attribute :role, :atom,
      constraints: [one_of: [:user, :manager, :admin, :super_admin, :system]],
      default: :user
  end

  relationships do
    belongs_to :organization, AshDiagram.Flow.Org, public?: true
  end
end
