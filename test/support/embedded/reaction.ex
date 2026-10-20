defmodule AshDiagram.Embedded.Reaction do
  @moduledoc false
  use Ash.TypedStruct

  typed_struct do
    field :emoji, :string, allow_nil?: false
  end
end
