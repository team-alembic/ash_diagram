defmodule AshDiagram.Flow.NoDomainResource do
  @moduledoc false
  # This resource has `domain: nil`. A resource that more than one domain
  # lists has this setting.
  use Ash.Resource,
    domain: nil,
    authorizers: [Ash.Policy.Authorizer],
    validate_domain_inclusion?: false

  actions do
    defaults [:read]
  end

  attributes do
    uuid_primary_key :id
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
