defmodule AshDiagram.Flow.NoDomainResource do
  @moduledoc false
  # `domain: nil`, as for a resource that more than one domain lists.
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
