defmodule ExPool.Mixfile do
  use Mix.Project

  @url_docs "http://hexdocs.pm/expool"
  @url_github "https://github.com/zackehh/expool"

  def project do
    [
      app: :expool,
      name: "ExPool",
      description: "Simple process pooling and task submission",
      package: %{
        files: [ "LICENSE", "mix.exs", "README.md", "lib" ],
        licenses: [ "MIT" ],
        links: %{ "Docs" => @url_docs, "GitHub" => @url_github },
        maintainers: [ "Isaac Whitfield" ]
      },
      version: "0.0.1",
      elixir: "~> 1.1",
      deps: deps(Mix.env),
      docs: [
        extras: [ "README.md" ],
        source_ref: "master",
        source_url: @url_github
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps(:docs) do
    [
      { :earmark, "~> 0.1",  optional: true },
      { :ex_doc,  "~> 0.10", optional: true }
    ]
  end
  defp deps(_) do
    [ ]
  end
end
