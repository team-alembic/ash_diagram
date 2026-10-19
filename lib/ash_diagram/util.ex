defmodule AshDiagram.Util do
  @moduledoc false

  @doc """
  Build display names for modules, keyed by module.

  `:full` uses the complete module name. `:short` drops the namespace that all
  modules share, but always keeps at least the last part of every name.
  """
  @spec module_names(modules :: [module()], name_option :: :full | :short) :: %{
          module() => String.t()
        }
  def module_names(modules, name_option)
  def module_names(modules, :full), do: Map.new(modules, &{&1, inspect(&1)})

  def module_names(modules, :short) do
    shared_length = modules |> Enum.map(&namespace_parts/1) |> common_prefix() |> length()

    Map.new(modules, fn module ->
      {module, module |> Module.split() |> Enum.drop(shared_length) |> Enum.join(".")}
    end)
  end

  @spec namespace_parts(module :: module()) :: [String.t()]
  defp namespace_parts(module), do: module |> Module.split() |> Enum.drop(-1)

  @spec common_prefix(lists :: [[String.t()]]) :: [String.t()]
  defp common_prefix(lists)
  defp common_prefix([]), do: []

  defp common_prefix(lists) do
    Enum.reduce(lists, fn list, acc ->
      acc
      |> Enum.zip(list)
      |> Enum.take_while(fn {a, b} -> a == b end)
      |> Enum.map(&elem(&1, 0))
    end)
  end

  @doc """
  Sanitize a string that can't be escaped and use their closest visual
  UTF-8 counterpart where it makes sense.
  """
  @spec sanitize_non_escapable_string(
          subject :: iodata(),
          disallowed_characters :: String.pattern() | Regex.t()
        ) ::
          String.t()
  def sanitize_non_escapable_string(subject, disallowed_characters) do
    disallowed? =
      case disallowed_characters do
        %Regex{} = regex -> &Regex.match?(regex, &1)
        pattern -> &(:binary.matches(&1, pattern) != [])
      end

    subject
    |> IO.iodata_to_binary()
    |> String.replace(disallowed_characters, &safe_replacement(&1, disallowed?))
  end

  @spec safe_replacement(
          character :: String.t(),
          disallowed? :: (character :: String.t() -> boolean())
        ) :: String.t()
  defp safe_replacement(character, disallowed?) do
    replacement = confusable_replacement(character)

    cond do
      not disallowed?.(replacement) -> replacement
      disallowed?.("�") -> ""
      true -> "�"
    end
  end

  @spec confusable_replacement(character :: String.t()) :: String.t()
  defp confusable_replacement(character)
  defp confusable_replacement("!"), do: "ǃ"
  defp confusable_replacement("\""), do: "“"
  defp confusable_replacement("#"), do: "＃"
  defp confusable_replacement("$"), do: "＄"
  defp confusable_replacement("%"), do: "％"
  defp confusable_replacement("&"), do: "＆"
  defp confusable_replacement("'"), do: "‘"
  defp confusable_replacement("+"), do: "＋"
  defp confusable_replacement(","), do: "，"
  defp confusable_replacement("."), do: "．"
  defp confusable_replacement("/"), do: "／"
  defp confusable_replacement(":"), do: "："
  defp confusable_replacement(";"), do: "；"
  defp confusable_replacement("<"), do: "＜"
  defp confusable_replacement("="), do: "＝"
  defp confusable_replacement(">"), do: "＞"
  defp confusable_replacement("?"), do: "？"
  defp confusable_replacement("@"), do: "＠"
  defp confusable_replacement("\\"), do: "＼"
  defp confusable_replacement("^"), do: "＾"
  defp confusable_replacement("`"), do: "｀"
  defp confusable_replacement("{"), do: "｛"
  defp confusable_replacement("|"), do: "｜"
  defp confusable_replacement("}"), do: "｝"
  defp confusable_replacement("~"), do: "～"
  defp confusable_replacement(_other), do: "�"
end
