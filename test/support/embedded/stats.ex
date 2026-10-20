defmodule AshDiagram.Embedded.Stats do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field :likes, :integer, allow_nil?: false
    field :reactions, {:array, AshDiagram.Embedded.Reaction}
  end
end
