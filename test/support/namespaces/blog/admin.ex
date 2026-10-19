defmodule AshDiagram.Namespaces.Blog.Admin do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshDiagram.Namespaces.Blog.Admin.Moderator
  end
end
