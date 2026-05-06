# AnovaVisualizer

Elixir module to visualize ANOVA and Tukey's HSD analysis results created using the [anova](https://hex.pm/packages/anova) Elixir library.

## Installation

```elixir
def deps do
  [
    {:anova_visualizer, "~> 1.2.0"}
  ]
end
```

## Usage in Livebook

```elixir

# Add dependencies
Mix.install([
  {:anova, "~> 0.6.1"},
  {:anova_visualizer, "~> 1.2.0"}
])

# Your results data
results = %{
  anova: %{...},
  post_hoc_test: %{...}
}

# Create visualization with auto-generated group names ("Group 1", "Group 2", ...)
AnovaVisualizer.visualize(results)

# Optionally provide a custom title
AnovaVisualizer.visualize(results, "My Experiment")

# Optionally provide a list of group names
AnovaVisualizer.visualize(results, "My Experiment", ["Control", "Treatment A", "Treatment B"])
```

## Key Features

* Group Means Comparison - Bar chart showing means and confidence intervals for each group
* Effect Size Comparison - Bar chart with color-coded significance
* Statistical Summaries
  * ANOVA summary with interpretations
  * Complete ANOVA table
  * Tukey's HSD summary
  * Detailed pairwise comparison cards