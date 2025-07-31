defmodule AshDiagram.Dummy do
  @moduledoc false
  @behaviour AshDiagram

  @type t() :: %__MODULE__{content: iodata()}

  @enforce_keys [:content]
  defstruct [:content]

  @impl true
  def compose(%__MODULE__{content: content}), do: content
end
