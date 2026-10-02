defmodule Mix.Tasks.AshDiagram.GeneratePolicyChartsTest do
  # Not async: the task writes files next to test/support/flow/*.ex, and the
  # tests change the Mix shell.
  use ExUnit.Case, async: false

  alias Mix.Tasks.AshDiagram.GeneratePolicyCharts

  @source_dir Path.expand("../../support/flow", __DIR__)

  setup do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      @source_dir |> Path.join("*-policy-flowchart.*") |> Path.wildcard() |> Enum.each(&File.rm!/1)
    end)
  end

  @spec output(name :: String.t()) :: Path.t()
  defp output(name), do: Path.join(@source_dir, name)

  test "raises without --only or --all" do
    assert_raise Mix.Error, ~r/Must pass the `--only` option or the `--all` option/, fn ->
      GeneratePolicyCharts.run([])
    end
  end

  test "--all writes a flowchart for each resource with policies" do
    GeneratePolicyCharts.run(["--all"])

    assert File.read!(output("user-policy-flowchart.mmd")) =~ "flowchart"
    assert File.read!(output("org-policy-flowchart.mmd")) =~ "flowchart"

    assert_received {:mix_shell, :info, ["Generated Mermaid Flow Chart for AshDiagram.Flow.User (" <> _rest]}
  end

  test "--only writes the flowchart for the resource in that file" do
    GeneratePolicyCharts.run(["--only", "test/support/flow/user.ex"])

    assert File.exists?(output("user-policy-flowchart.mmd"))
    refute File.exists?(output("org-policy-flowchart.mmd"))
  end

  test "--format md writes a Markdown code block" do
    GeneratePolicyCharts.run(["--all", "--format", "md"])

    assert File.read!(output("user-policy-flowchart.md")) =~ ~r/\A```mermaid\n/
  end

  test "raises on an unknown format" do
    assert_raise Mix.Error, ~r/Invalid format `gif`/, fn ->
      GeneratePolicyCharts.run(["--all", "--format", "gif"])
    end
  end
end
