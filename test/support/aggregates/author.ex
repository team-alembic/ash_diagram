defmodule AshDiagram.Aggregates.Author do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Aggregates.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
  end

  relationships do
    has_many :posts, AshDiagram.Aggregates.Post do
      public?(true)
    end
  end

  aggregates do
    count :post_count, :posts do
      public?(true)
    end

    exists :has_posts?, :posts do
      public?(true)
    end

    max :top_score, :posts, :score do
      public?(true)
    end

    list :titles, :posts, :title do
      public?(true)
    end

    custom :joined_titles, :posts, :string do
      public?(true)
      implementation AshDiagram.Aggregates.StringAgg
    end
  end
end
