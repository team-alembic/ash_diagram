defmodule AshDiagram.Embedded.Author do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :name, :string do
      public?(true)
    end
  end
end
