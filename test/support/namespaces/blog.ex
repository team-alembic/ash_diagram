defmodule AshDiagram.Namespaces.Blog do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshDiagram.Namespaces.Blog.Author
    resource AshDiagram.Namespaces.Blog.Post
  end
end
