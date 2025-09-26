defmodule AshDiagram.Fixture do
  @moduledoc """
  Provides functions to read and write fixtures for testing.
  """

  use ExUnit.CaseTemplate

  @fixture_dir [__DIR__, "..", "fixtures"] |> Path.join() |> Path.expand()

  @doc "Path to fixture"
  @spec fixture_path(path :: Path.t()) :: Path.t()
  def fixture_path(path), do: Path.join(@fixture_dir, path)

  @doc "Read fixture"
  @spec read_fixture(path :: Path.t()) :: String.t()
  def read_fixture(path), do: path |> fixture_path() |> File.read!()

  @doc "Write fixture"
  @spec write_fixture(path :: Path.t(), content :: iodata()) :: :ok
  def write_fixture(path, content), do: path |> fixture_path() |> File.write!(content)
end
