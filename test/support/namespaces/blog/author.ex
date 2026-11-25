defmodule AshDiagram.Namespaces.Blog.Author do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Namespaces.Blog,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public?(true)
    end
  end

  relationships do
    has_many :posts, AshDiagram.Namespaces.Blog.Post do
      public?(true)
    end
  end
end
