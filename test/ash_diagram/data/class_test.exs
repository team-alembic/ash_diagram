defmodule AshDiagram.Data.ClassTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Data.Class
  alias AshDiagram.Flow.User

  doctest Class

  describe inspect(&Class.for_resources/1) do
    @tag :tmp_dir
    test "creates diagram from resources", %{tmp_dir: tmp_dir} do
      diagram = Class.for_resources([User, AshDiagram.Flow.Org])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               classDiagram
                 class `dummy`["♡"]
                 class `AshDiagram.Flow.Org`["Org"] {
                   +UUID id
                   +?String name
                   +update() : update~Org~
                   +create() : create~Org~
                   +destroy() : destroy~Org~
                   +read() : read~Org~
                   +by_name(String name) : read~Org~
                   +archive() : update~Org~
                 }
                 class `AshDiagram.Flow.User`["User"] {
                   +UUID id
                   +?String first_name
                   +?String last_name
                   +?String email
                   +?Boolean approved?
                   +destroy() : destroy~User~
                   +read() : read~User~
                   +for_org(UUID org) : read~User~
                   +by_name(String name) : read~User~
                   +create(UUID org) : create~User~
                   +update() : update~User~
                   +approve() : update~User~
                   +unapprove() : update~User~
                   +report(String reason) : action~?Boolean~
                 }
                 `AshDiagram.Flow.Org` "*" o--* "0..1" `AshDiagram.Flow.User`
               """

      assert png = AshDiagram.render(diagram, format: :png)

      out_path = Path.join(tmp_dir, "out.png")

      File.write!(out_path, png)

      diff_path = Path.join(tmp_dir, "diff.png")

      assert_alike(
        out_path,
        fixture_path("class.png"),
        diff_path
      )
    end

    test "creates diagram from resource" do
      diagram = Class.for_resources([User])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               classDiagram
                 class `dummy`["♡"]
                 class `AshDiagram.Flow.User`["User"] {
                   +UUID id
                   +?String first_name
                   +?String last_name
                   +?String email
                   +?Boolean approved?
                   +destroy() : destroy~User~
                   +read() : read~User~
                   +for_org(UUID org) : read~User~
                   +by_name(String name) : read~User~
                   +create(UUID org) : create~User~
                   +update() : update~User~
                   +approve() : update~User~
                   +unapprove() : update~User~
                   +report(String reason) : action~?Boolean~
                 }
                 `AshDiagram.Flow.Org` "*" o--* "0..1" `AshDiagram.Flow.User`
               """
    end
  end
end
