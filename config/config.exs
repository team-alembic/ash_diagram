import Config

config :logger, level: :info

case config_env() do
  :test -> config :ash_diagram, ash_domains: [AshDiagram.Flow.Domain]
  _env -> :ok
end
