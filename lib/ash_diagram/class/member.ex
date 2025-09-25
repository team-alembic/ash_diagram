defmodule AshDiagram.Class.Member do
  @moduledoc """
  Represents a member in the Class Diagram.
  """

  alias AshDiagram.Class.Field
  alias AshDiagram.Class.Method

  @type t() :: Method.t() | Field.t()

  @visibilities %{
    public: "+",
    private: "-",
    protected: "#",
    package: "~"
  }
  @visibility_keys Map.keys(@visibilities)
  visibility_typespec = Enum.reduce(@visibility_keys, &{:|, [], [&1, &2]})
  @type visibility() :: unquote(visibility_typespec)

  @type type() :: iodata() | {:generic, iodata(), type()}

  @doc false
  @spec compose(member :: t(), indent :: iodata()) :: iodata()
  def compose(member, indent)
  def compose(%Method{} = method, indent), do: Method.compose(method, indent)
  def compose(%Field{} = field, indent), do: Field.compose(field, indent)

  @doc false
  @spec compose_visibility(visibility :: visibility()) :: iodata()
  def compose_visibility(visibility) when visibility in @visibility_keys do
    Map.fetch!(@visibilities, visibility)
  end

  @doc false
  @spec compose_type(type :: type()) :: iodata()
  def compose_type(type)
  def compose_type({:generic, name, inner_type}), do: [name, ?~, compose_type(inner_type), ?~]
  def compose_type(type), do: type
end
