import Config

config :logger, level: :info

case config_env() do
  :test -> config :ash_diagram, ash_domains: [AshDiagram.Flow.Domain]
  _env -> :ok
end

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshDiagram.MixProject,
    github_handle_lookup?: true,
    repository_url: "https://github.com/team-alembic/ash_diagram",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: "README.md",
    version_tag_prefix: "v"
end
