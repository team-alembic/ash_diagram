defmodule AshDiagram.VisualAssertions do
  @moduledoc """
  Provides visual assertions for testing image similarity.
  """

  import ExUnit.Assertions

  @spec assert_alike(left :: Path.t(), right :: Path.t(), diff :: Path.t()) :: :ok
  def assert_alike(left, right, diff) do
    compare_path = System.find_executable("compare")
    assert is_binary(compare_path), "ImageMagic Compare is not installed"

    {_, status} =
      System.cmd(compare_path, [
        "-quiet",
        left,
        right,
        diff
      ])

    assert status == 0,
      message: "Image #{left} and #{right} are not alike, check #{diff} for details"
  end
end
