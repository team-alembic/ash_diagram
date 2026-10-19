defmodule AshDiagram.Namespaces.Blog.Admin.Moderator do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Namespaces.Blog.Admin,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
  end
end
