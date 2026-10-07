defmodule AshDiagram.Aggregates.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Aggregates.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      public?(true)
    end

    attribute :score, :integer do
      public?(true)
    end
  end

  relationships do
    belongs_to :author, AshDiagram.Aggregates.Author do
      public?(true)
    end
  end
end
