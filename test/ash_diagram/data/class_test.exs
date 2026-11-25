defmodule AshDiagram.Data.ClassTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Aggregates.Author
  alias AshDiagram.Aggregates.Post
  alias AshDiagram.Data.Class
  alias AshDiagram.Flow.NoDomainResource
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flow.SharedDomainA
  alias AshDiagram.Flow.SharedDomainB
  alias AshDiagram.Flow.User

  doctest Class

  describe inspect(&Class.for_resources/1) do
    test "creates diagram from a resource without a domain" do
      diagram = Class.for_resources([NoDomainResource])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() =~ "AshDiagram.Flow.NoDomainResource"
    end

    test "creates diagram from resources" do
      diagram = Class.for_resources([User, Org])

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
    end

    @tag :tmp_dir
    @tag :visual
    test "renders diagram from resources", %{tmp_dir: tmp_dir} do
      diagram = Class.for_resources([User, Org])

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

    test "resolves aggregate types" do
      diagram = Class.for_resources([Author, Post])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               classDiagram
                 class `AshDiagram.Aggregates.Author`["Author"] {
                   +UUID id
                   +Integer post_count
                   +Boolean has_posts?
                   +Integer top_score
                   +String[] titles
                   +String joined_titles
                 }
                 class `AshDiagram.Aggregates.Post`["Post"] {
                   +UUID id
                   +?String title
                   +?Integer score
                   +?UUID author_id
                 }
                 `AshDiagram.Aggregates.Author` "*" o--* "0..1" `AshDiagram.Aggregates.Post`
               """
    end
  end

  describe inspect(&Class.for_domains/1) do
    test "draws a resource that two domains list only once, with the extensions of both domains" do
      composed =
        [SharedDomainA, SharedDomainB]
        |> Class.for_domains()
        |> AshDiagram.compose()
        |> IO.iodata_to_binary()

      assert composed |> String.split("class `AshDiagram.Flow.NoDomainResource`") |> length() == 2
      refute composed =~ ~s|[""]|
      # AshDiagram.DummyExtension, from SharedDomainA, adds this entry.
      assert composed =~ "♡"
    end
  end
end
