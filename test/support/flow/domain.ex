defmodule AshDiagram.Flow.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshDiagram.Flow.User
    resource AshDiagram.Flow.Org
    allow_unregistered? true
  end
end
