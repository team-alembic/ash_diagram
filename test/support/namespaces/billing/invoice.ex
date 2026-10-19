defmodule AshDiagram.Namespaces.Billing.Invoice do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Namespaces.Billing,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :amount, :decimal do
      public?(true)
    end
  end

  relationships do
    belongs_to :author, AshDiagram.Namespaces.Blog.Author do
      public?(true)
      allow_nil?(false)
    end
  end
end
