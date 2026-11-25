defmodule AshDiagram.Embedded.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshDiagram.Embedded.Post
  end
end
