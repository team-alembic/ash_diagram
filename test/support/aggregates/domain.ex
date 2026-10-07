defmodule AshDiagram.Aggregates.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshDiagram.Aggregates.Author
    resource AshDiagram.Aggregates.Post
  end
end
