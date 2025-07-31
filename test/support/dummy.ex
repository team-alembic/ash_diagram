defmodule AshChart.Dummy do
  @moduledoc false
  @behaviour AshChart

  @type t() :: %__MODULE__{content: iodata()}

  @enforce_keys [:content]
  defstruct [:content]

  @impl true
  def compose(%__MODULE__{content: content}), do: content
end
