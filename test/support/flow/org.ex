defmodule AshDiagram.Flow.Org do
  @moduledoc false
  use Ash.Resource, domain: AshDiagram.Flow.Domain, data_layer: Ash.DataLayer.Mnesia

  resource do
    description "Org model"
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
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public?(true)
    end
  end

  relationships do
    has_many :users, AshDiagram.Flow.User do
      public?(true)
    end
  end
end
