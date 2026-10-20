defmodule AshDiagram.Embedded.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Embedded.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      public?(true)
    end

    attribute :comments, {:array, AshDiagram.Embedded.Comment} do
      public?(true)
    end

    attribute :author, AshDiagram.Embedded.Author do
      public?(true)
    end

    attribute :note, AshDiagram.Embedded.Note
  end
end
