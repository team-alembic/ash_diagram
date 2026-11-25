defmodule AshDiagram.UtilTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Util
  alias MyApp.Billing.Invoice
  alias MyApp.Blog.Admin
  alias MyApp.Blog.Post

  doctest Util

  describe inspect(&Util.module_names/2) do
    test "uses the complete module name with :full" do
      assert Util.module_names([Post], :full) == %{Post => "MyApp.Blog.Post"}
    end

    test "drops the shared namespace with :short" do
      assert Util.module_names([Post, Invoice], :short) == %{
               Post => "Blog.Post",
               Invoice => "Billing.Invoice"
             }
    end

    test "keeps the last part of a single module with :short" do
      assert Util.module_names([Post], :short) == %{Post => "Post"}
    end

    test "keeps the name of a module that prefixes another module with :short" do
      assert Util.module_names([MyApp.Blog, Admin], :short) == %{
               MyApp.Blog => "Blog",
               Admin => "Blog.Admin"
             }
    end

    test "handles no modules" do
      assert Util.module_names([], :short) == %{}
      assert Util.module_names([], :full) == %{}
    end
  end

  describe inspect(&Util.sanitize_non_escapable_string/2) do
    test "replaces individual special characters" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~]/

      assert Util.sanitize_non_escapable_string("!", disallowed) == "ǃ"
      assert Util.sanitize_non_escapable_string("\"", disallowed) == "“"
      assert Util.sanitize_non_escapable_string("#", disallowed) == "＃"
      assert Util.sanitize_non_escapable_string("$", disallowed) == "＄"
      assert Util.sanitize_non_escapable_string("%", disallowed) == "％"
      assert Util.sanitize_non_escapable_string("&", disallowed) == "＆"
      assert Util.sanitize_non_escapable_string("'", disallowed) == "‘"
      assert Util.sanitize_non_escapable_string("+", disallowed) == "＋"
      assert Util.sanitize_non_escapable_string(",", disallowed) == "，"
      assert Util.sanitize_non_escapable_string(".", disallowed) == "．"
      assert Util.sanitize_non_escapable_string("/", disallowed) == "／"
      assert Util.sanitize_non_escapable_string(":", disallowed) == "："
      assert Util.sanitize_non_escapable_string(";", disallowed) == "；"
      assert Util.sanitize_non_escapable_string("<", disallowed) == "＜"
      assert Util.sanitize_non_escapable_string("=", disallowed) == "＝"
      assert Util.sanitize_non_escapable_string(">", disallowed) == "＞"
      assert Util.sanitize_non_escapable_string("?", disallowed) == "？"
      assert Util.sanitize_non_escapable_string("@", disallowed) == "＠"
      assert Util.sanitize_non_escapable_string("\\", disallowed) == "＼"
      assert Util.sanitize_non_escapable_string("^", disallowed) == "＾"
      assert Util.sanitize_non_escapable_string("`", disallowed) == "｀"
      assert Util.sanitize_non_escapable_string("{", disallowed) == "｛"
      assert Util.sanitize_non_escapable_string("|", disallowed) == "｜"
      assert Util.sanitize_non_escapable_string("}", disallowed) == "｝"
      assert Util.sanitize_non_escapable_string("~", disallowed) == "～"
    end

    test "replaces characters when confusable replacement is also disallowed" do
      assert Util.sanitize_non_escapable_string("!", ["!", "ǃ"]) == "�"
      assert Util.sanitize_non_escapable_string("!", ["!", "ǃ", "�"]) == ""
    end

    test "replaces multiple special characters in a single string" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~()]/

      assert Util.sanitize_non_escapable_string(
               "Hello! How are you? I'm fine.",
               disallowed
             ) == "Helloǃ How are you？ I‘m fine．"

      assert Util.sanitize_non_escapable_string(
               "user@example.com",
               disallowed
             ) == "user＠example．com"

      assert Util.sanitize_non_escapable_string(
               ~s({key: "value"}),
               disallowed
             ) == ~s(｛key： “value“｝)

      assert Util.sanitize_non_escapable_string(
               "100% < $50.00 & > #1",
               disallowed
             ) == "100％ ＜ ＄50．00 ＆ ＞ ＃1"
    end

    test "replaces characters not in the mapping with �" do
      disallowed = ~r/[()[\]]/

      assert Util.sanitize_non_escapable_string("(", disallowed) == "�"
      assert Util.sanitize_non_escapable_string(")", disallowed) == "�"
      assert Util.sanitize_non_escapable_string("[", disallowed) == "�"
      assert Util.sanitize_non_escapable_string("]", disallowed) == "�"
      assert Util.sanitize_non_escapable_string("(test)", disallowed) == "�test�"
      assert Util.sanitize_non_escapable_string("[array]", disallowed) == "�array�"
    end

    test "leaves strings without special characters unchanged" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~]/

      assert Util.sanitize_non_escapable_string("Hello World", disallowed) == "Hello World"
      assert Util.sanitize_non_escapable_string("test123", disallowed) == "test123"
      assert Util.sanitize_non_escapable_string("CamelCase", disallowed) == "CamelCase"
      assert Util.sanitize_non_escapable_string("snake_case", disallowed) == "snake_case"
      assert Util.sanitize_non_escapable_string("UPPERCASE", disallowed) == "UPPERCASE"
    end

    test "handles empty strings" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~]/

      assert Util.sanitize_non_escapable_string("", disallowed) == ""
    end

    test "handles mixed content with normal text and special characters" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~]/

      assert Util.sanitize_non_escapable_string(
               "The price is $99.99 (including 10% tax)!",
               disallowed
             ) == "The price is ＄99．99 (including 10％ tax)ǃ"

      assert Util.sanitize_non_escapable_string(
               "Visit https://example.com/page?query=value&other=123",
               disallowed
             ) == "Visit https：／／example．com／page？query＝value＆other＝123"
    end

    test "works with string patterns instead of regex" do
      assert Util.sanitize_non_escapable_string("Hello! World!", "!") == "Helloǃ Worldǃ"
      assert Util.sanitize_non_escapable_string("user@domain", "@") == "user＠domain"
      assert Util.sanitize_non_escapable_string("a/b/c", "/") == "a／b／c"
    end

    test "handles iodata as input" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~]/
      iodata = ["Hello", ?!, " ", "World", ?.]

      assert Util.sanitize_non_escapable_string(iodata, disallowed) == "Helloǃ World．"
    end

    test "handles complex iodata with nested lists" do
      disallowed = ~r/[!"#$%&'+,.\/:;<=>?@\\^`{|}~]/
      iodata = [["user", ?@], ["example", ?., "com"]]

      assert Util.sanitize_non_escapable_string(iodata, disallowed) == "user＠example．com"
    end
  end
end
