defmodule AshDiagram.Embedded.Summary do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field :headline, :string, allow_nil?: false
    field :words, :integer
  end
end
