defmodule AshDiagram.ClassTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Class
  alias AshDiagram.Class.Relationship.Pointer

  doctest Class

  describe inspect(&Class.compose/1) do
    test "renders basic diagram" do
      diagram = %Class{
        title: "Order example",
        entries: [
          %Class.Class{
            id: "CUSTOMER",
            label: "A customer",
            members: [
              %Class.Field{
                name: "id",
                visibility: :private,
                type: "UUID"
              },
              %Class.Method{
                name: "place_order",
                visibility: :public,
                type: {:generic, "Result", "Order"},
                arguments: [{"products", {:generic, "List", "Product"}}]
              }
            ]
          },
          %Class.Class{
            id: "ORDER",
            generic: "Product"
          },
          %Class.Relationship{
            left: %Pointer{class: "CUSTOMER", type: :association, cardinality: "1"},
            right: %Pointer{class: "ORDER", type: :association, cardinality: "0..*"},
            style: :solid,
            label: "places"
          },
          %Class.Relationship{
            left: %Pointer{class: "ORDER", type: :association, cardinality: "1"},
            right: %Pointer{class: "LINE-ITEM", type: :association, cardinality: "1..*"},
            style: :solid,
            label: "contains"
          },
          %Class.Relationship{
            left: %Pointer{class: "CUSTOMER", type: :association, cardinality: "1..*"},
            right: %Pointer{class: "DELIVERY-ADDRESS", type: :association, cardinality: "1..*"},
            style: :solid,
            label: "uses"
          }
        ]
      }

      assert diagram |> Class.compose() |> IO.iodata_to_binary() ==
               """
               ---
               title: "Order example"
               ---
               classDiagram
                 class `CUSTOMER`["A customer"] {
                   -UUID id
                   +place_order(List~Product~ products) : Result~Order~
                 }
                 class `ORDER`~Product~
                 `CUSTOMER` "1" <--> "0..*" `ORDER` : places
                 `ORDER` "1" <--> "1..*" `LINE-ITEM` : contains
                 `CUSTOMER` "1..*" <--> "1..*" `DELIVERY-ADDRESS` : uses
               """

      assert AshDiagram.render(diagram, format: :svg)
    end
  end
end
