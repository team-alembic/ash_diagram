defmodule Mix.AshDiagramTest do
  # Not async: the tests change the Mix shell, the renderer config and the
  # current directory, which are global, and they write next to
  # test/support/flow/*.ex.
  use ExUnit.Case, async: false

  alias AshDiagram.Flow.Domain
  alias AshDiagram.Flow.User

  # Two modules in this one source file, so their diagram files conflict.
  defmodule One, do: @moduledoc(false)
  defmodule Two, do: @moduledoc(false)

  @source_dir Path.expand("../support/flow", __DIR__)
  @diagram %AshDiagram.Dummy{content: "flowchart TD\n  a --> b"}

  setup do
    previous_shell = Mix.shell()
    previous_renderer = Application.fetch_env(:ash_diagram, :renderer)
    Mix.shell(Mix.Shell.Process)
    Application.put_env(:ash_diagram, :renderer, AshDiagram.StubRenderer)
    remove_outputs()

    on_exit(fn ->
      Mix.shell(previous_shell)
      remove_outputs()

      case previous_renderer do
        {:ok, renderer} -> Application.put_env(:ash_diagram, :renderer, renderer)
        :error -> Application.delete_env(:ash_diagram, :renderer)
      end
    end)
  end

  @spec remove_outputs() :: :ok
  defp remove_outputs do
    @source_dir |> Path.join("*-test-flow.*") |> Path.wildcard() |> Enum.each(&File.rm!/1)
  end

  @spec output(name :: String.t()) :: Path.t()
  defp output(name), do: Path.join(@source_dir, name)

  @spec build(module :: module()) :: {AshDiagram.t(), String.t()}
  defp build(module), do: {@diagram, "Generated #{inspect(module)}"}

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

    test "raises when the module has no source file" do
      # A module compiled from forms, like one compiled with the
      # `deterministic` option, has no :source in its compile info.
      forms = [{:attribute, 1, :module, :ash_diagram_no_source}, {:attribute, 1, :export, []}]
      {:ok, module, binary} = :compile.forms(forms, [:binary, :deterministic])
      {:module, ^module} = :code.load_binary(module, ~c"nofile", binary)

      assert_raise Mix.Error, ~r/source file of :ash_diagram_no_source is not known/, fn ->
        Mix.AshDiagram.source(module)
      end
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

    test "raises on an unknown format, and lists the valid ones" do
      assert_raise Mix.Error, ~r/Invalid format `gif`.\nValid options are `plain`, `md`, /, fn ->
        Mix.AshDiagram.validate_format!("gif")
      end
    end
  end

  describe "file/3" do
    test "puts the file next to the source, with the suffix and the extension" do
      assert Mix.AshDiagram.file("/app/lib/my_app/accounts.ex", "mermaid-er-diagram", "mmd") ==
               "/app/lib/my_app/accounts-mermaid-er-diagram.mmd"
    end
  end

  describe "write_all/4" do
    test "plain writes the Mermaid source to a .mmd file" do
      assert Mix.AshDiagram.write_all([Domain], "test-flow", "plain", &build/1) ==
               [output("domain-test-flow.mmd")]

      assert File.read!(output("domain-test-flow.mmd")) == "flowchart TD\n  a --> b"
      assert_received {:mix_shell, :info, ["Generated AshDiagram.Flow.Domain (" <> _rest]}
    end

    test "md wraps the source in a mermaid code block" do
      Mix.AshDiagram.write_all([Domain], "test-flow", "md", &build/1)

      assert File.read!(output("domain-test-flow.md")) ==
               "```mermaid\nflowchart TD\n  a --> b\n```\n"
    end

    @tag :tmp_dir
    test "svg, pdf and png go through the configured renderer", %{tmp_dir: tmp_dir} do
      # In an empty directory, so that a mermaidConfig.json in the project
      # root does not change the options.
      File.cd!(tmp_dir, fn ->
        for format <- ~w[svg pdf png] do
          Mix.AshDiagram.write_all([Domain], "test-flow", format, &build/1)

          assert File.read!(output("domain-test-flow.#{format}")) ==
                   "rendered format=#{format}\nflowchart TD\n  a --> b"
        end
      end)
    end

    @tag :tmp_dir
    test "gives mermaidConfig.json to the renderer when the file exists", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir, fn ->
        File.write!("mermaidConfig.json", "{}")
        config_file = Path.join(File.cwd!(), "mermaidConfig.json")

        Mix.AshDiagram.write_all([Domain], "test-flow", "svg", &build/1)

        assert File.read!(output("domain-test-flow.svg")) ==
                 "rendered format=svg config_file=#{config_file}\nflowchart TD\n  a --> b"
      end)
    end

    test "writes a module that is in the list twice only once" do
      assert Mix.AshDiagram.write_all([Domain, Domain], "test-flow", "plain", &build/1) ==
               [output("domain-test-flow.mmd")]

      assert_received {:mix_shell, :info, ["Generated AshDiagram.Flow.Domain" <> _rest]}
      refute_received {:mix_shell, :info, ["Generated AshDiagram.Flow.Domain" <> _rest]}
    end

    test "raises before it writes when two modules write to the same file" do
      assert_raise Mix.Error, ~r/More than one module writes to the same diagram file/, fn ->
        Mix.AshDiagram.write_all([One, Two], "test-flow", "plain", &build/1)
      end

      refute File.exists?(Path.expand("ash_diagram_test-test-flow.mmd", __DIR__))
    end

    test "writes the other diagrams when one fails, then raises with the module and the file" do
      build = fn
        User -> raise "the renderer failed"
        module -> build(module)
      end

      message =
        ~r/Could not write the diagram of AshDiagram.Flow.User to .*user-test-flow.mmd:\nthe renderer failed/

      assert_raise Mix.Error, message, fn ->
        Mix.AshDiagram.write_all([User, Domain], "test-flow", "plain", build)
      end

      assert File.exists?(output("domain-test-flow.mmd"))
      refute File.exists?(output("user-test-flow.mmd"))
    end
  end
end
