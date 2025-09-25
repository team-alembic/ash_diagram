defmodule AshDiagram.Flowchart.StyleTest do
  use ExUnit.Case, async: true

  alias AshDiagram.Flowchart.Style

  doctest Style

  describe inspect(&Style.compose/1) do
    test "renders class definition style" do
      style = %Style{
        type: :class,
        name: "important",
        properties: %{"fill" => "#ff0000", "stroke" => "#000000"}
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  classDef important fill:#ff0000,stroke:#000000\n"
    end

    test "renders node class assignment" do
      style = %Style{
        type: :node,
        id: "A",
        classes: ["important", "highlighted"]
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  class A important,highlighted\n"
    end

    test "renders single node class assignment" do
      style = %Style{
        type: :node,
        id: "B",
        classes: ["error"]
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  class B error\n"
    end

    test "renders direct node styling" do
      style = %Style{
        type: :direct,
        id: "C",
        properties: %{"fill" => "#00ff00"}
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  style C fill:#00ff00\n"
    end

    test "renders click event" do
      style = %Style{
        type: :click,
        id: "button",
        action: "alert('Clicked!')"
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  click button \"alert('Clicked!')\"\n"
    end

    test "renders href link" do
      style = %Style{
        type: :href,
        id: "link_node",
        url: "https://example.com"
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               ~s(  click link_node href "https://example.com"\n)
    end

    test "renders href link with tooltip" do
      style = %Style{
        type: :href,
        id: "tooltip_link",
        url: "https://example.com",
        tooltip: "Visit Example"
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               ~s(  click tooltip_link href "https://example.com" "Visit Example"\n)
    end

    test "quotes node ID with spaces" do
      style = %Style{
        type: :direct,
        id: "node with spaces",
        properties: %{"fill" => "#blue"}
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               """
                 style node with spaces fill:#blue
               """
    end

    test "handles multiple CSS properties" do
      style = %Style{
        type: :class,
        name: "complex",
        properties: %{
          "fill" => "#ffffff",
          "stroke" => "#000000",
          "stroke-width" => "2px",
          "color" => "#333333"
        }
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  classDef complex color:#333333,fill:#ffffff,stroke:#000000,stroke-width:2px\n"
    end

    test "handles empty properties map" do
      style = %Style{
        type: :class,
        name: "empty",
        properties: %{}
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  classDef empty \n"
    end

    test "handles empty classes list" do
      style = %Style{
        type: :node,
        id: "lonely",
        classes: []
      }

      assert style |> Style.compose() |> IO.iodata_to_binary() ==
               "  class lonely \n"
    end
  end
end
