defmodule AshDiagram.Flow.Org do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Flow.Domain,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer]

  resource do
    description "Org model"
  end

  policies do
    # Complex nested policy with multiple checks
    policy action_type(:read) do
      authorize_if actor_present()
      forbid_if actor_attribute_equals(:role, :banned)
    end

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, :admin)

      authorize_if expr(
                     actor(:role) == :manager and
                       relates_to_actor_via(:members)
                   )
    end

    policy action_type(:destroy) do
      forbid_if relates_to_actor_via([:members, :users])
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Policy with complex expression
    policy action(:archive) do
      authorize_if expr(
                     actor(:role) in [:admin, :manager] and
                       is_nil(archived_at)
                   )
    end
  end

  identities do
    identity :unique_name, [:name], pre_check_with: AshDiagram.Flow.Domain
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    read :by_name do
      argument :name, :string, allow_nil?: false
      get? true

      filter expr(name == ^arg(:name))
    end

    update :archive do
      accept []
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public?(true)
    end

    attribute :archived_at, :utc_datetime do
      public?(false)
    end
  end

  relationships do
    has_many :users, AshDiagram.Flow.User do
      public?(true)
    end
  end
end
