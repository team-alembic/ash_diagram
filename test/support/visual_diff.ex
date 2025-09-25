defmodule AshDiagram.VisualAssertions do
  @moduledoc """
  Provides visual assertions for testing image similarity.
  """

  import ExUnit.Assertions

  require Logger

  @spec assert_alike(actual :: Path.t(), expectation :: Path.t(), diff :: Path.t()) :: :ok
  def assert_alike(actual, expectation, diff) do
    compare_path = System.find_executable("compare")
    assert is_binary(compare_path), "ImageMagic Compare is not installed"

    {_, status} =
      System.cmd(compare_path, [
        "-quiet",
        actual,
        expectation,
        diff
      ])

    case System.get_env("OVERWRITE_VISUALS") do
      truthy when truthy in ~w[true 1 yes y] and status > 0 ->
        Logger.warning("#{actual} and #{expectation} differ, overwriting #{expectation}")

        File.cp!(actual, expectation)

      truthy when truthy in ~w[true 1 yes y] and status == 0 ->
        :ok

      _falsy ->
        assert status == 0,
          message: """
          Image #{actual} and #{expectation} are not alike.
          Check #{diff} for details.
          Use OVERWRITE_VISUALS=true to overwrite expectation.\
          """
    end

    :ok
  end
end
