defmodule Mix.Tasks.AshDiagram.GenerateResourceDiagramsTest do
  # Not async: the task writes files next to test/support/flow/domain.ex,
  # and the tests change the Mix shell.
  use ExUnit.Case, async: false

  alias Mix.Tasks.AshDiagram.GenerateResourceDiagrams

  @source_dir Path.expand("../../support/flow", __DIR__)

  setup do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      @source_dir |> Path.join("domain-mermaid-*") |> Path.wildcard() |> Enum.each(&File.rm!/1)
    end)
  end

  @spec output(name :: String.t()) :: Path.t()
  defp output(name), do: Path.join(@source_dir, name)

  test "writes a class diagram by default" do
    GenerateResourceDiagrams.run([])

    assert File.read!(output("domain-mermaid-class-diagram.mmd")) =~ ~r/\AclassDiagram\n/

    assert_received {:mix_shell, :info, ["Generated Class Diagram for AshDiagram.Flow.Domain (" <> _rest]}
  end

  test "--type er writes an ER diagram" do
    GenerateResourceDiagrams.run(["--type", "er"])

    assert File.read!(output("domain-mermaid-er-diagram.mmd")) =~ ~r/\AerDiagram\n/
  end

  test "--type architecture writes a C4 diagram" do
    GenerateResourceDiagrams.run(["--type", "architecture"])

    assert File.read!(output("domain-mermaid-architecture-diagram.mmd")) =~ ~r/\AC4Context\n/
  end

  test "--format md writes a Markdown code block" do
    GenerateResourceDiagrams.run(["--format", "md"])

    assert File.read!(output("domain-mermaid-class-diagram.md")) =~
             ~r/\A```mermaid\nclassDiagram\n/
  end

  test "--only with the domain file writes the diagram" do
    GenerateResourceDiagrams.run(["--only", "test/support/flow/domain.ex"])

    assert File.exists?(output("domain-mermaid-class-diagram.mmd"))
  end

  test "--only with another file writes nothing" do
    GenerateResourceDiagrams.run(["--only", "lib/ash_diagram.ex"])

    refute File.exists?(output("domain-mermaid-class-diagram.mmd"))
    refute_received {:mix_shell, :info, ["Generated" <> _rest]}
  end

  test "raises on an unknown type" do
    assert_raise Mix.Error, ~r/Invalid resource diagram type `state`/, fn ->
      GenerateResourceDiagrams.run(["--type", "state"])
    end
  end

  test "raises on an unknown format" do
    assert_raise Mix.Error, ~r/Invalid format `gif`/, fn ->
      GenerateResourceDiagrams.run(["--format", "gif"])
    end
  end
end
