defmodule AshDiagram.Data.EntityRelationshipTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Aggregates.Author
  alias AshDiagram.Aggregates.Post
  alias AshDiagram.Data.EntityRelationship
  alias AshDiagram.Embedded
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flow.User

  doctest EntityRelationship

  describe inspect(&EntityRelationship.for_resources/1) do
    test "creates diagram from resources" do
      diagram = EntityRelationship.for_resources([User, Org])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               erDiagram
                 "dummy"["♡"]
                 "AshDiagram.Flow.Org"["Org"] {
                   UUID id
                   String？ name
                 }
                 "AshDiagram.Flow.User"["User"] {
                   UUID id
                   String？ first_name
                   String？ last_name
                   String？ email
                   Boolean？ approved？
                 }
                 "AshDiagram.Flow.Org" }o--o| "AshDiagram.Flow.User" : ""
               """
    end

    @tag :tmp_dir
    @tag :visual
    test "renders diagram from resources", %{tmp_dir: tmp_dir} do
      diagram = EntityRelationship.for_resources([User, Org])

      assert png = AshDiagram.render(diagram, format: :png)

      out_path = Path.join(tmp_dir, "out.png")

      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "diff.png")

      assert_alike(
        out_path,
        fixture_path("entity_relationship.png"),
        diff_path
      )
    end

    test "creates diagram from resource" do
      diagram = EntityRelationship.for_resources([User])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               erDiagram
                 "dummy"["♡"]
                 "AshDiagram.Flow.User"["User"] {
                   UUID id
                   String？ first_name
                   String？ last_name
                   String？ email
                   Boolean？ approved？
                 }
                 "AshDiagram.Flow.Org" }o--o| "AshDiagram.Flow.User" : ""
               """
    end

    test "resolves aggregate types" do
      diagram = EntityRelationship.for_resources([Author, Post])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               erDiagram
                 "AshDiagram.Aggregates.Author"["Author"] {
                   UUID id
                   Integer post_count
                   Boolean has_posts？
                   Integer top_score
                   String[] titles
                   String joined_titles
                 }
                 "AshDiagram.Aggregates.Post"["Post"] {
                   UUID id
                   String？ title
                   Integer？ score
                   UUID？ author_id
                 }
                 "AshDiagram.Aggregates.Author" }o--o| "AshDiagram.Aggregates.Post" : ""
               """
    end

    test "accepts embedded resources" do
      assert [Embedded.Post, Embedded.Comment]
             |> EntityRelationship.for_resources()
             |> AshDiagram.compose() ==
               [Embedded.Domain] |> EntityRelationship.for_domains() |> AshDiagram.compose()
    end

    test "only follows private attributes to embedded resources with show_private?" do
      public_only = [Embedded.Post] |> EntityRelationship.for_resources() |> AshDiagram.compose()

      with_private =
        [Embedded.Post]
        |> EntityRelationship.for_resources(show_private?: true)
        |> AshDiagram.compose()

      refute IO.iodata_to_binary(public_only) =~ ~s("AshDiagram.Embedded.Note")
      assert IO.iodata_to_binary(with_private) =~ ~s("AshDiagram.Embedded.Note")
    end

    # TODO: support union and maps
    test "does not find embedded resources in union and map types" do
      diagram = [Embedded.Container] |> EntityRelationship.for_resources() |> AshDiagram.compose()

      refute IO.iodata_to_binary(diagram) =~ ~s("AshDiagram.Embedded.Author")
    end

    test "accepts typed structs" do
      assert [Embedded.Post, Embedded.Meta]
             |> EntityRelationship.for_resources()
             |> AshDiagram.compose() ==
               [Embedded.Domain] |> EntityRelationship.for_domains() |> AshDiagram.compose()
    end
  end

  describe inspect(&EntityRelationship.for_domains/1) do
    test "adds embedded resources and typed structs as related entities" do
      diagram = EntityRelationship.for_domains([Embedded.Domain])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               erDiagram
                 "AshDiagram.Embedded.Author"["Author"] {
                   String？ name
                 }
                 "AshDiagram.Embedded.Comment"["Comment"] {
                   String？ text
                   Author author
                 }
                 "AshDiagram.Embedded.Post"["Post"] {
                   UUID id
                   String？ title
                   Comment[]？ comments
                   Author author
                   Author？ editor
                   Meta？ meta
                   Stats？ stats
                   Struct？ raw
                 }
                 "AshDiagram.Embedded.Meta"["Meta"] {
                   Integer views
                   String[]？ tags
                 }
                 "AshDiagram.Embedded.Reaction"["Reaction"] {
                   String emoji
                 }
                 "AshDiagram.Embedded.Stats"["Stats"] {
                   Integer likes
                   Reaction[]？ reactions
                 }
                 "AshDiagram.Embedded.Comment" ||--|| "AshDiagram.Embedded.Author" : "author"
                 "AshDiagram.Embedded.Post" ||--|| "AshDiagram.Embedded.Author" : "author"
                 "AshDiagram.Embedded.Post" ||--o{ "AshDiagram.Embedded.Comment" : "comments"
                 "AshDiagram.Embedded.Post" ||--o| "AshDiagram.Embedded.Author" : "editor"
                 "AshDiagram.Embedded.Post" ||--o| "AshDiagram.Embedded.Meta" : "meta"
                 "AshDiagram.Embedded.Post" ||--o| "AshDiagram.Embedded.Stats" : "stats"
                 "AshDiagram.Embedded.Stats" ||--o{ "AshDiagram.Embedded.Reaction" : "reactions"
               """
    end

    test "leaves out typed structs only used in actions" do
      diagram = [Embedded.Domain] |> EntityRelationship.for_domains() |> AshDiagram.compose()

      refute IO.iodata_to_binary(diagram) =~ ~s("AshDiagram.Embedded.Summary")
    end

    test "leaves out composition labels without :compositions in labels" do
      diagram =
        [Embedded.Domain] |> EntityRelationship.for_domains(labels: []) |> AshDiagram.compose()

      assert IO.iodata_to_binary(diagram) =~
               ~s("AshDiagram.Embedded.Post" ||--o{ "AshDiagram.Embedded.Comment" : ""\n)
    end
  end
end
