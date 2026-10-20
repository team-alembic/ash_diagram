defmodule AshDiagram.Embedded.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshDiagram.Embedded.Domain,
    data_layer: Ash.DataLayer.Ets

  alias AshDiagram.Embedded.Author
  alias AshDiagram.Embedded.Meta
  alias AshDiagram.Embedded.Summary

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      public?(true)
    end

    attribute :comments, {:array, AshDiagram.Embedded.Comment} do
      public?(true)
    end

    attribute :author, Author do
      allow_nil?(false)
      public?(true)
    end

    # Who edited the post last, nil while never edited
    attribute :editor, Author do
      public?(true)
    end

    attribute :note, AshDiagram.Embedded.Note

    attribute :meta, :struct do
      constraints instance_of: Meta
      public?(true)
    end

    attribute :stats, AshDiagram.Embedded.Stats do
      public?(true)
    end

    attribute :raw, :struct do
      public?(true)
    end
  end

  actions do
    action :summarize, :struct do
      constraints instance_of: Meta

      argument :previous, {:array, :struct} do
        constraints items: [instance_of: Meta]
      end

      run fn _input, _context -> {:ok, nil} end
    end

    action :digest, Summary do
      run fn _input, _context -> {:ok, nil} end
    end

    action :preview, {:array, Summary} do
      run fn _input, _context -> {:ok, []} end
    end

    action :revise, :string do
      argument :draft, Summary do
        public?(false)
      end

      run fn _input, _context -> {:ok, nil} end
    end
  end
end
