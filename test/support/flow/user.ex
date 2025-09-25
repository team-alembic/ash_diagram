defmodule AshDiagram.Flow.User do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Flow.Domain,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshDiagram.DummyExtension]

  resource do
    description "User model"
  end

  policies do
    # Simple authorization policy
    policy action_type(:read) do
      authorize_if always()
    end

    # Complex policy with conditions
    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if relates_to_actor_via(:org)
    end

    # Forbid policy
    policy action_type(:destroy) do
      forbid_if actor_attribute_equals(:role, :guest)
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Policy with multiple conditions
    policy action(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if expr(approved == true and relates_to_actor_via(:org))
    end

    # Bypass policy
    bypass actor_attribute_equals(:role, :super_admin) do
      authorize_if always()
    end
  end

  actions do
    default_accept [:first_name, :last_name, :email]
    defaults [:read, :destroy]

    read :for_org do
      argument :org, :uuid, allow_nil?: false

      filter(expr(org_id == ^arg(:org)))
    end

    read :by_name do
      argument :name, :string, allow_nil?: false

      filter(expr(first_name == ^arg(:name)))
    end

    create :create do
      description """
      Creating is serious business.
      For serious people.
      """

      argument :org, :uuid, allow_nil?: false
      change manage_relationship(:org, type: :append_and_remove)
    end

    update :update do
      primary? true
    end

    update :approve do
      accept []
      change set_attribute(:approved, true)
    end

    update :unapprove do
      accept []
      change set_attribute(:approved, false)
    end

    action :report, :boolean do
      allow_nil? true
      argument :reason, :string, allow_nil?: false
    end
  end

  code_interface do
    define :to_approved, action: :approve
  end

  attributes do
    uuid_primary_key :id, description: "PK"
    attribute :first_name, :string, description: "User's first name", public?: true
    attribute :last_name, :string, description: "User's last name", public?: true

    attribute :email, :string,
      description: """
      User's email address.
      This doesn't have any validation on it.
      """,
      public?: true

    attribute :approved, :boolean do
      description "Is the user approved?"
    end

    attribute :role, :atom do
      description "User's role"
      constraints one_of: [:guest, :user, :admin, :super_admin]
      default :user
    end
  end

  relationships do
    belongs_to :org, AshDiagram.Flow.Org do
      public?(true)
      attribute_public?(false)
    end
  end
end
