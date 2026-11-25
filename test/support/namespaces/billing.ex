defmodule AshDiagram.Namespaces.Billing do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshDiagram.Namespaces.Billing.Invoice
  end
end
