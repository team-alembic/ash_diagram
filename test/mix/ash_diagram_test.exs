defmodule Mix.AshDiagramTest do
  # Not async: the tests change the Mix shell, the renderer config and the
  # current directory, which are global.
  use ExUnit.Case, async: false

  alias AshDiagram.Flow.Domain

  setup do
    Mix.shell(Mix.Shell.Process)
    previous = Application.fetch_env(:ash_diagram, :renderer)
    Application.put_env(:ash_diagram, :renderer, AshDiagram.StubRenderer)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)

      case previous do
        {:ok, renderer} -> Application.put_env(:ash_diagram, :renderer, renderer)
        :error -> Application.delete_env(:ash_diagram, :renderer)
      end
    end)
  end

  describe "domains/0" do
    test "reads :ash_domains of the current Mix project" do
      assert Mix.AshDiagram.domains() == [Domain]
    end
  end

  describe "only/1" do
    test "is nil when no --only is given" do
      assert Mix.AshDiagram.only([]) == nil
    end

    test "expands every --only value" do
      assert Mix.AshDiagram.only(only: "a.ex", format: "md", only: "b.ex") ==
               [Path.expand("a.ex"), Path.expand("b.ex")]
    end
  end

  describe "source/1" do
    test "gives the source file of a module as a string" do
      assert Mix.AshDiagram.source(Domain) == Path.expand("test/support/flow/domain.ex")
    end
  end

  describe "selected?/2" do
    test "selects every module when only is nil" do
      assert Mix.AshDiagram.selected?(Domain, nil)
    end

    test "selects a module whose source file is in only" do
      assert Mix.AshDiagram.selected?(Domain, [Path.expand("test/support/flow/domain.ex")])
    end

    test "does not select a module whose source file is not in only" do
      refute Mix.AshDiagram.selected?(Domain, [Path.expand("lib/ash_diagram.ex")])
    end
  end

  describe "validate_format!/1" do
    test "accepts each format" do
      for format <- ~w[plain md svg pdf png] do
        assert Mix.AshDiagram.validate_format!(format) == format
      end
    end

    test "raises on an unknown format" do
      assert_raise Mix.Error, ~r/Invalid format `gif`/, fn ->
        Mix.AshDiagram.validate_format!("gif")
      end
    end
  end

  describe "file/3" do
    test "puts the file next to the source, with the suffix and the extension" do
      assert Mix.AshDiagram.file(~c"/app/lib/my_app/accounts.ex", "mermaid-er-diagram", "mmd") ==
               "/app/lib/my_app/accounts-mermaid-er-diagram.mmd"
    end
  end

  describe "write_diagram/5" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      %{
        source: Path.join(tmp_dir, "accounts.ex"),
        diagram: %AshDiagram.Dummy{content: "flowchart TD\n  a --> b"}
      }
    end

    test "plain writes the Mermaid source to a .mmd file", context do
      path = Mix.AshDiagram.write_diagram(context.source, "flow", "plain", context.diagram, "Generated")

      assert path == Path.join(context.tmp_dir, "accounts-flow.mmd")
      assert File.read!(path) == "flowchart TD\n  a --> b"
      assert_received {:mix_shell, :info, ["Generated (" <> _rest]}
    end

    test "md wraps the source in a mermaid code block", context do
      path = Mix.AshDiagram.write_diagram(context.source, "flow", "md", context.diagram, "Generated")

      assert path == Path.join(context.tmp_dir, "accounts-flow.md")
      assert File.read!(path) == "```mermaid\nflowchart TD\n  a --> b\n```\n"
    end

    test "svg, pdf and png go through the configured renderer", context do
      for format <- ~w[svg pdf png] do
        path = Mix.AshDiagram.write_diagram(context.source, "flow", format, context.diagram, "Generated")

        assert path == Path.join(context.tmp_dir, "accounts-flow.#{format}")
        assert File.read!(path) == "rendered format=#{format}\nflowchart TD\n  a --> b"
      end
    end

    test "gives mermaidConfig.json to the renderer when the file exists", context do
      File.cd!(context.tmp_dir, fn ->
        File.write!("mermaidConfig.json", "{}")
        config_file = Path.join(File.cwd!(), "mermaidConfig.json")

        path = Mix.AshDiagram.write_diagram(context.source, "flow", "svg", context.diagram, "Generated")

        assert File.read!(path) ==
                 "rendered format=svg config_file=#{config_file}\nflowchart TD\n  a --> b"
      end)
    end
  end
end
