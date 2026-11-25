defmodule AshDiagram.Embedded.Note do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :text, :string do
      public?(true)
    end
  end
end
