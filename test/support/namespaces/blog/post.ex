defmodule AshDiagram.Namespaces.Blog.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Namespaces.Blog,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      public?(true)
    end
  end

  relationships do
    belongs_to :author, AshDiagram.Namespaces.Blog.Author do
      public?(true)
    end
  end
end
