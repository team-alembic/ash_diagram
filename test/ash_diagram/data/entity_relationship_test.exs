defmodule AshDiagram.Data.EntityRelationshipTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Data.EntityRelationship
  alias AshDiagram.Flow.User

  doctest EntityRelationship

  describe inspect(&EntityRelationship.for_resources/1) do
    @tag :tmp_dir
    test "creates diagram from resources", %{tmp_dir: tmp_dir} do
      diagram = EntityRelationship.for_resources([User, AshDiagram.Flow.Org])

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
  end
end
