defmodule ExBreak.MixProject do
  use Mix.Project

  @version "0.0.8"
  @github_url "https://github.com/jclem/ex_break"

  def project do
    [
      app: :ex_break,
      description: "A circuit breaker for Elixir apps",
      version: @version,
      package: package(),
      name: "ExBreak",
      homepage_url: @github_url,
      source_url: @github_url,
      docs: docs(),
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExBreak.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:earmark, "~> 1.3", only: :dev},
      {:ex_doc, "~> 0.20.2", only: :dev}
    ]
  end

  defp package do
    [
      name: :ex_break,
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url}
    ]
  end

  defp docs do
    [
      extras: ~w(README.md LICENSE.md),
      main: "readme",
      source_ref: "v#{@version}"
    ]
  end
end
