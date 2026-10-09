defmodule AshDiagram.Flow.SharedDomainA do
  @moduledoc false
  # This domain lists a resource that has `domain: nil`. It also has an
  # AshDiagram extension, which must apply to the diagrams of the domain.
  use Ash.Domain, extensions: [AshDiagram.DummyExtension], validate_config_inclusion?: false

  resources do
    resource AshDiagram.Flow.NoDomainResource
  end
end

defmodule AshDiagram.Flow.SharedDomainB do
  @moduledoc false
  # This domain lists the same resource as AshDiagram.Flow.SharedDomainA.
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshDiagram.Flow.NoDomainResource
  end
end
