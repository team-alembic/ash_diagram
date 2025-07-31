defmodule AshDiagram.EntityRelationshipTest do
  use ExUnit.Case, async: true

  alias AshDiagram.EntityRelationship

  doctest EntityRelationship

  describe inspect(&EntityRelationship.compose/1) do
    test "renders basic diagram" do
      diagram = %EntityRelationship{
        title: "Order example",
        entries: [
          %EntityRelationship.Relationship{
            left: {"CUSTOMER", :exactly_one},
            right: {"ORDER", :zero_or_more},
            identifying?: true,
            label: "places"
          },
          %EntityRelationship.Relationship{
            left: {"ORDER", :exactly_one},
            right: {"LINE-ITEM", :one_or_more},
            identifying?: true,
            label: "contains"
          },
          %EntityRelationship.Relationship{
            left: {"CUSTOMER", :one_or_more},
            right: {"DELIVERY-ADDRESS", :one_or_more},
            identifying?: false,
            label: "uses"
          }
        ]
      }

      assert diagram |> EntityRelationship.compose() |> IO.iodata_to_binary() ==
               """
               ---
               title: "Order example"
               ---
               erDiagram
                 "CUSTOMER" ||--o{ "ORDER" : "places"
                 "ORDER" ||--|{ "LINE-ITEM" : "contains"
                 "CUSTOMER" }|..|{ "DELIVERY-ADDRESS" : "uses"
               """

      assert AshDiagram.render(diagram, format: :svg)
    end

    test "renders complex diagram" do
      diagram = %EntityRelationship{
        entries: [
          %EntityRelationship.Relationship{
            left: {"CUSTOMER", :exactly_one},
            right: {"ORDER", :zero_or_more},
            identifying?: true,
            label: "places"
          },
          %EntityRelationship.Entity{
            id: "CUSTOMER",
            attributes: [
              %EntityRelationship.Attribute{name: "name", type: "string"},
              %EntityRelationship.Attribute{name: "custNumber", type: "string"},
              %EntityRelationship.Attribute{name: "sector", type: "string"}
            ]
          },
          %EntityRelationship.Relationship{
            left: {"ORDER", :exactly_one},
            right: {"LINE-ITEM", :one_or_more},
            identifying?: true,
            label: "contains"
          },
          %EntityRelationship.Entity{
            id: "ORDER",
            attributes: [
              %EntityRelationship.Attribute{name: "orderNumber", type: "int"},
              %EntityRelationship.Attribute{name: "deliveryAddress", type: "string"}
            ]
          },
          %EntityRelationship.Entity{
            id: "LINE-ITEM",
            attributes: [
              %EntityRelationship.Attribute{name: "productCode", type: "string"},
              %EntityRelationship.Attribute{name: "quantity", type: "int"},
              %EntityRelationship.Attribute{name: "pricePerUnit", type: "float"}
            ]
          }
        ]
      }

      assert diagram |> EntityRelationship.compose() |> IO.iodata_to_binary() ==
               """
               erDiagram
                 "CUSTOMER" ||--o{ "ORDER" : "places"
                 "CUSTOMER" {
                   string name
                   string custNumber
                   string sector
                 }
                 "ORDER" ||--|{ "LINE-ITEM" : "contains"
                 "ORDER" {
                   int orderNumber
                   string deliveryAddress
                 }
                 "LINE-ITEM" {
                   string productCode
                   int quantity
                   float pricePerUnit
                 }
               """

      assert AshDiagram.render(diagram, format: :svg)
    end
  end
end
