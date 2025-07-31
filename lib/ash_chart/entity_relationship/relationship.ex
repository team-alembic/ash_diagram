defmodule AshChart.EntityRelationship.Relationship do
  @moduledoc """
  Represents a relationship between two entities in the Entity Relationship
  Diagram (ERD).
  """

  @cardinalities %{
    zero_or_one: {"|o", "o|"},
    exactly_one: {"||", "||"},
    zero_or_more: {"}o", "o{"},
    one_or_more: {"}|", "|{"}
  }
  @cardinality_labels Map.keys(@cardinalities)
  cardinality_typespec = Enum.reduce(@cardinality_labels, &{:|, [], [&1, &2]})
  @type cardinality() :: unquote(cardinality_typespec)

  @type t() :: %__MODULE__{
          left: {iodata(), cardinality()},
          right: {iodata(), cardinality()},
          identifying?: boolean(),
          label: iodata() | nil
        }
  @enforce_keys [:left, :right, :identifying?]
  defstruct [:left, :right, :identifying?, label: nil]

  @doc false
  @spec compose(relation :: t()) :: iodata()
  def compose(%__MODULE__{left: left, right: right, identifying?: identifying?, label: label}) do
    {left, left_cardinality} = left
    {right, right_cardinality} = right

    [
      "  ",
      left |> IO.iodata_to_binary() |> inspect(),
      " ",
      cardinality(left_cardinality, :left),
      if identifying? do
        "--"
      else
        ".."
      end,
      cardinality(right_cardinality, :right),
      " ",
      right |> IO.iodata_to_binary() |> inspect(),
      if label do
        [" : ", label |> IO.iodata_to_binary() |> inspect()]
      else
        []
      end,
      "\n"
    ]
  end

  @spec cardinality(cardinality :: cardinality(), side :: :left | :right) :: iodata()
  defp cardinality(cardinality, side)

  defp cardinality(cardinality, :left) do
    {left, _right} = Map.fetch!(@cardinalities, cardinality)
    left
  end

  defp cardinality(cardinality, :right) do
    {_left, right} = Map.fetch!(@cardinalities, cardinality)
    right
  end
end
