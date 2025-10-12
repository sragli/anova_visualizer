# AnovaVisualizer

Elixir module that generates visualization for ANOVA and Tukey's HSD analysis results created using the `anova` Elixir library.

## Installation

```elixir
def deps do
  [
    {:anova_visualizer, "~> 0.1.0"}
  ]
end
```

## Usage in Livebook

```elixir

# Add dependencies
Mix.install([
  {:kino, "~> 0.12"},
  {:kino_vega_lite, "~> 0.1"},
  {:jason, "~> 1.4"}
])

# Your results data
results = %{
  anova: %{...},
  post_hoc_test: %{...}
}

# Create visualization
AnovaVisualizer.visualize(results)
```

## Key Features

* Group Means Comparison - Bar chart showing means and confidence intervals for each group
* Effect Size Comparison - Bar chart with color-coded significance
* Statistical Summaries
  * ANOVA summary with interpretations
  * Complete ANOVA table
  * Tukey's HSD summary
  * Detailed pairwise comparison cards