defmodule AshDiagram.Embedded.Meta do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field :views, :integer, allow_nil?: false
    field :tags, {:array, :string}
  end
end
