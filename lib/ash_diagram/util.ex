defmodule AshDiagram.Util do
  @moduledoc false

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
