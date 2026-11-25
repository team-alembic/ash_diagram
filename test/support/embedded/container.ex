defmodule AshDiagram.Embedded.Container do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  alias AshDiagram.Embedded.Author

  attributes do
    attribute :union_author, :union do
      public?(true)
      constraints types: [author: [type: Author]]
    end

    attribute :map_author, :map do
      public?(true)
      constraints fields: [author: [type: Author]]
    end
  end
end
