defmodule AshDiagram.Data.EntityRelationshipTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Aggregates.Author
  alias AshDiagram.Aggregates.Post
  alias AshDiagram.Data.EntityRelationship
  alias AshDiagram.Flow.NoDomainResource
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flow.User

  doctest EntityRelationship

  describe inspect(&EntityRelationship.for_resources/1) do
    test "creates diagram from a resource without a domain" do
      diagram = EntityRelationship.for_resources([NoDomainResource])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() =~ "AshDiagram.Flow.NoDomainResource"
    end

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
  end
end
