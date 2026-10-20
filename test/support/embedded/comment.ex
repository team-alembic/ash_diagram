defmodule AshDiagram.Embedded.Comment do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :text, :string do
      public?(true)
    end

    attribute :author, AshDiagram.Embedded.Author do
      public?(true)
    end
  end
end
