defmodule AshDiagram.Data.ClassTest do
  use ExUnit.Case, async: true

  import AshDiagram.Fixture
  import AshDiagram.VisualAssertions

  alias AshDiagram.Aggregates.Author
  alias AshDiagram.Aggregates.Post
  alias AshDiagram.Data.Class
  alias AshDiagram.Embedded
  alias AshDiagram.Flow.Org
  alias AshDiagram.Flow.User

  doctest Class

  describe inspect(&Class.for_resources/1) do
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

    test "accepts embedded resources" do
      assert [Embedded.Post, Embedded.Comment] |> Class.for_resources() |> AshDiagram.compose() ==
               [Embedded.Domain] |> Class.for_domains() |> AshDiagram.compose()
    end

    test "only follows private attributes to embedded resources with show_private?" do
      public_only = [Embedded.Post] |> Class.for_resources() |> AshDiagram.compose()
      with_private = [Embedded.Post] |> Class.for_resources(show_private?: true) |> AshDiagram.compose()

      refute IO.iodata_to_binary(public_only) =~ "`AshDiagram.Embedded.Note`"
      assert IO.iodata_to_binary(with_private) =~ "`AshDiagram.Embedded.Note`"
    end

    # TODO: support union and maps
    test "does not find embedded resources in union and map types" do
      diagram = [Embedded.Container] |> Class.for_resources() |> AshDiagram.compose()

      refute IO.iodata_to_binary(diagram) =~ "`AshDiagram.Embedded.Author`"
    end

    test "accepts typed structs" do
      assert [Embedded.Post, Embedded.Meta] |> Class.for_resources() |> AshDiagram.compose() ==
               [Embedded.Domain] |> Class.for_domains() |> AshDiagram.compose()
    end

    test "follows private action arguments without show_private?, like the method signature" do
      diagram =
        [Embedded.Post] |> Class.for_resources() |> AshDiagram.compose() |> IO.iodata_to_binary()

      assert diagram =~ "+revise(?Summary draft) : action~String~"

      assert diagram =~
               "`AshDiagram.Embedded.Post` ..> `AshDiagram.Embedded.Summary` : digest, preview, revise\n"
    end
  end

  describe inspect(&Class.for_domains/1) do
    test "adds embedded resources and typed structs as compositions" do
      diagram = Class.for_domains([Embedded.Domain])

      assert diagram |> AshDiagram.compose() |> IO.iodata_to_binary() ==
               """
               classDiagram
                 class `AshDiagram.Embedded.Author`["Author"] {
                   +?String name
                   +create() : create~Author~
                   +read() : read~Author~
                   +update() : update~Author~
                   +destroy() : destroy~Author~
                 }
                 class `AshDiagram.Embedded.Comment`["Comment"] {
                   +?String text
                   +Author author
                   +create() : create~Comment~
                   +read() : read~Comment~
                   +update() : update~Comment~
                   +destroy() : destroy~Comment~
                 }
                 class `AshDiagram.Embedded.Post`["Post"] {
                   +UUID id
                   +?String title
                   +?Comment[] comments
                   +Author author
                   +?Author editor
                   +?Meta meta
                   +?Stats stats
                   +?Struct raw
                   +summarize(?Meta[] previous) : action~Meta~
                   +digest() : action~Summary~
                   +preview() : action~Summary[]~
                   +revise(?Summary draft) : action~String~
                 }
                 class `AshDiagram.Embedded.Meta`["Meta"] {
                   +Integer views
                   +?String[] tags
                 }
                 class `AshDiagram.Embedded.Reaction`["Reaction"] {
                   +String emoji
                 }
                 class `AshDiagram.Embedded.Stats`["Stats"] {
                   +Integer likes
                   +?Reaction[] reactions
                 }
                 class `AshDiagram.Embedded.Summary`["Summary"] {
                   +String headline
                   +?Integer words
                 }
                 `AshDiagram.Embedded.Comment` "1" *-- "1" `AshDiagram.Embedded.Author` : author
                 `AshDiagram.Embedded.Post` "1" *-- "1" `AshDiagram.Embedded.Author` : author
                 `AshDiagram.Embedded.Post` "1" *-- "*" `AshDiagram.Embedded.Comment` : comments
                 `AshDiagram.Embedded.Post` "1" *-- "0..1" `AshDiagram.Embedded.Author` : editor
                 `AshDiagram.Embedded.Post` "1" *-- "0..1" `AshDiagram.Embedded.Meta` : meta
                 `AshDiagram.Embedded.Post` "1" *-- "0..1" `AshDiagram.Embedded.Stats` : stats
                 `AshDiagram.Embedded.Stats` "1" *-- "*" `AshDiagram.Embedded.Reaction` : reactions
                 `AshDiagram.Embedded.Post` ..> `AshDiagram.Embedded.Summary` : digest, preview, revise
               """
    end

    test "leaves out composition labels without :compositions in labels" do
      diagram = [Embedded.Domain] |> Class.for_domains(labels: []) |> AshDiagram.compose()

      assert IO.iodata_to_binary(diagram) =~
               ~s(`AshDiagram.Embedded.Post` "1" *-- "*" `AshDiagram.Embedded.Comment`\n)
    end

    test "leaves out dependency labels without :dependencies in labels" do
      diagram =
        [Embedded.Domain] |> Class.for_domains(labels: [:compositions]) |> AshDiagram.compose()

      assert IO.iodata_to_binary(diagram) =~
               "`AshDiagram.Embedded.Post` ..> `AshDiagram.Embedded.Summary`\n"
    end
  end
end
