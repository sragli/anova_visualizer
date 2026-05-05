defmodule AnovaVisualizer.MixProject do
  use Mix.Project

  def project do
    [
      app: :anova_visualizer,
      version: "1.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "ANOVA_Visualizer",
      source_url: "https://github.com/sragli/anova_visualizer",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:anova, "~> 0.7.2"},
      {:kino, "~> 0.7"},
      {:kino_vega_lite, "~> 0.1.10"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Visualizer for ANOVA results."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sragli/anova_visualizer"}
    ]
  end

  defp docs() do
    [
      main: "ANOVA_Visualizer",
      extras: ["README.md", "LICENSE", "CHANGELOG"]
    ]
  end
end
