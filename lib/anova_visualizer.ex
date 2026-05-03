defmodule AnovaVisualizer do
  @moduledoc """
  Generates interactive VegaLite visualizations for ANOVA and Tukey's HSD analysis results
  using Kino.VegaLite for Livebook integration.
  """

  @doc """
  Creates a comprehensive visualization layout for ANOVA and Tukey's HSD results.

  ## Example

      # Run ANOVA and post-hoc test, then visualize:
      # groups
      # |> ANOVA.one_way()
      # |> TukeyHSD.test(0.05)
      # |> AnovaVisualizer.visualize()
  """
  def visualize(%{
        anova: anova_result,
        post_hoc_test: post_hoc_result
      }, title \\ "ANOVA One-Way with Tukey's HSD Post-Hoc Test") do
    Kino.Layout.grid(
      [
        render_header(title),
        render_anova_summary(anova_result),
        render_anova_table(anova_result),
        render_group_means_chart(anova_result),
        render_posthoc_summary(post_hoc_result),
        render_pairwise_comparisons(post_hoc_result),
        render_confidence_intervals(post_hoc_result),
        render_effect_size_comparison(post_hoc_result)
      ],
      columns: 1
    )
  end

  defp render_header(title) do
    content = """
    # 📊 #{title}

    ---
    """

    Kino.Markdown.new(content)
  end

  defp render_anova_summary(anova) do
    significance =
      if anova.test_results.p_value < 0.05, do: "✅ **Significant**", else: "❌ Not Significant"

    """
    ## 🔬 ANOVA Summary Statistics

    | Metric | Value |
    |--------|-------|
    | **Number of Groups** | #{anova.summary.groups} |
    | **Total Observations** | #{anova.summary.total_observations} |
    | **Overall Mean** | #{format_number(anova.summary.overall_mean)} |
    | **F-Statistic** | #{format_number(anova.test_results.f_statistic)} |
    | **p-Value** | #{format_scientific(anova.test_results.p_value)} |
    | **Significance** | #{significance} |
    | **Eta Squared (η²)** | #{format_number(anova.test_results.eta_squared)} (#{interpret_eta_squared(anova.test_results.eta_squared)}) |
    | **Omega Squared (ω²)** | #{format_number(anova.test_results.omega_squared)} |

    ---
    """
    |> Kino.Markdown.new()
  end

  defp render_anova_table(anova) do
    """
    ## 📋 ANOVA Table

    | Source | Sum of Squares | df | Mean Square | F-Statistic | p-Value |
    |--------|----------------|-------|-------------|-------------|---------|
    | **Between Groups** | #{format_number(anova.anova_table.between.ss)} | #{anova.anova_table.between.df} | #{format_number(anova.anova_table.between.ms)} | #{format_number(anova.test_results.f_statistic)} | #{format_scientific(anova.test_results.p_value)} |
    | **Within Groups** | #{format_number(anova.anova_table.within.ss)} | #{anova.anova_table.within.df} | #{format_number(anova.anova_table.within.ms)} | — | — |
    | **Total** | #{format_number(anova.anova_table.total.ss)} | #{anova.anova_table.total.df} | — | — | — |

    ---
    """
    |> Kino.Markdown.new()
  end

  defp render_group_means_chart(anova) do
    data =
      anova.summary.group_means
      |> Enum.with_index(1)
      |> Enum.map(fn {mean, idx} ->
        %{
          "group" => "Group #{idx}",
          "mean" => mean,
          "group_num" => idx
        }
      end)

    VegaLite.new(width: 600, height: 400, title: "Group Means Comparison")
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar, tooltip: true)
    |> VegaLite.encode_field(:x, "group",
      type: :nominal,
      title: "Group",
      axis: [label_angle: 0, label_font_size: 14]
    )
    |> VegaLite.encode_field(:y, "mean",
      type: :quantitative,
      title: "Mean Value",
      scale: [zero: true]
    )
    |> VegaLite.encode_field(:color, "group_num",
      type: :nominal,
      scale: [range: ["#667eea", "#764ba2"]],
      legend: false
    )
    |> VegaLite.encode(:tooltip, [
      [field: "group", type: :nominal, title: "Group"],
      [field: "mean", type: :quantitative, title: "Mean", format: ".2f"]
    ])
    |> Kino.VegaLite.new()
  end

  defp render_posthoc_summary(post_hoc) do
    significant_pairs =
      post_hoc.summary.significant_pairs
      |> Enum.map(fn {g1, g2} -> "Group #{g1} vs Group #{g2}" end)
      |> Enum.join(", ")

    """
    ## 📈 Tukey's HSD Post-Hoc Analysis Summary

    | Metric | Value |
    |--------|-------|
    | **Total Comparisons** | #{post_hoc.summary.total_comparisons} |
    | **Significant Comparisons** | #{post_hoc.summary.significant_comparisons} ✅ |
    | **Non-Significant Comparisons** | #{post_hoc.summary.non_significant_comparisons} |
    | **Significant Pairs** | #{significant_pairs} |
    | **Mean Difference (avg)** | #{format_number(post_hoc.summary.difference_stats.mean)} |
    | **Mean Effect Size** | #{format_number(post_hoc.summary.effect_size_stats.mean)} (#{interpret_cohens_d(post_hoc.summary.effect_size_stats.mean)}) |

    ---
    """
    |> Kino.Markdown.new()
  end

  defp render_pairwise_comparisons(post_hoc) do
    post_hoc.pairwise_comparisons
    |> Enum.map(&render_comparison_card/1)
    |> Kino.Layout.grid(columns: 1)
  end

  defp render_comparison_card(comp) do
    {group1, group2} = comp.groups
    {mean1, mean2} = comp.means

    sig_emoji = if comp.significant?, do: "✅", else: "❌"
    sig_text = if comp.significant?, do: "**Significant**", else: "Not Significant"
    effect_interp = interpret_cohens_d(comp.effect_size)

    """
    ### #{sig_emoji} Group #{group1} vs Group #{group2} - #{sig_text}

    #### Key Statistics

    | Statistic | Value |
    |-----------|-------|
    | **Mean Difference** | #{format_number(comp.difference)} |
    | **Group #{group1} Mean** | #{format_number(mean1)} |
    | **Group #{group2} Mean** | #{format_number(mean2)} |
    | **Q-Statistic** | #{format_number(comp.q_statistic)} |
    | **p-Value** | #{format_scientific(comp.p_value)} |
    | **Standard Error** | #{format_number(comp.standard_error)} |
    | **Effect Size (Cohen's d)** | #{format_number(comp.effect_size)} (#{effect_interp}) |
    | **#{trunc(comp.confidence_interval.level)}% CI Lower** | #{format_number(comp.confidence_interval.lower)} |
    | **#{trunc(comp.confidence_interval.level)}% CI Upper** | #{format_number(comp.confidence_interval.upper)} |

    ---
    """
    |> Kino.Markdown.new()
  end

  defp render_confidence_intervals(post_hoc) do
    # Create data for bars (mean difference)
    bar_data =
      post_hoc.pairwise_comparisons
      |> Enum.map(fn comp ->
        {g1, g2} = comp.groups

        %{
          "comparison" => "Group #{g1} vs #{g2}",
          "difference" => comp.difference,
          "ci_lower" => comp.confidence_interval.lower,
          "ci_upper" => comp.confidence_interval.upper,
          "significant" => if(comp.significant?, do: "Significant", else: "Not Significant")
        }
      end)

    VegaLite.new(width: 700, height: 400, title: "Mean Differences with 95% Confidence Intervals")
    |> VegaLite.data_from_values(bar_data)
    |> VegaLite.layers([
      # Bar layer for mean difference
      VegaLite.new()
      |> VegaLite.mark(:bar, tooltip: true)
      |> VegaLite.encode_field(:x, "comparison",
        type: :nominal,
        title: "Comparison",
        axis: [label_angle: 0]
      )
      |> VegaLite.encode_field(:y, "difference",
        type: :quantitative,
        title: "Mean Difference",
        scale: [zero: false]
      )
      |> VegaLite.encode_field(:color, "significant",
        type: :nominal,
        scale: [
          domain: ["Significant", "Not Significant"],
          range: ["#10b981", "#ef4444"]
        ],
        legend: [title: "Significance"]
      ),

      # Error bar layer for confidence intervals
      VegaLite.new()
      |> VegaLite.mark(:rule, color: "#1f2937", size: 2)
      |> VegaLite.encode_field(:x, "comparison", type: :nominal)
      |> VegaLite.encode_field(:y, "ci_lower", type: :quantitative)
      |> VegaLite.encode_field(:y2, "ci_upper"),

      # Tick marks at CI bounds
      VegaLite.new()
      |> VegaLite.mark(:tick, color: "#1f2937", size: 15, thickness: 2)
      |> VegaLite.encode_field(:x, "comparison", type: :nominal)
      |> VegaLite.encode_field(:y, "ci_lower", type: :quantitative),
      VegaLite.new()
      |> VegaLite.mark(:tick, color: "#1f2937", size: 15, thickness: 2)
      |> VegaLite.encode_field(:x, "comparison", type: :nominal)
      |> VegaLite.encode_field(:y, "ci_upper", type: :quantitative)
    ])
    |> VegaLite.encode(:tooltip, [
      [field: "comparison", type: :nominal, title: "Comparison"],
      [field: "difference", type: :quantitative, title: "Mean Difference", format: ".2f"],
      [field: "ci_lower", type: :quantitative, title: "95% CI Lower", format: ".2f"],
      [field: "ci_upper", type: :quantitative, title: "95% CI Upper", format: ".2f"],
      [field: "significant", type: :nominal, title: "Significant?"]
    ])
    |> Kino.VegaLite.new()
  end

  defp render_effect_size_comparison(post_hoc) do
    data =
      post_hoc.pairwise_comparisons
      |> Enum.map(fn comp ->
        {g1, g2} = comp.groups

        %{
          "comparison" => "Group #{g1} vs #{g2}",
          "effect_size" => comp.effect_size,
          "significant" => if(comp.significant?, do: "Significant", else: "Not Significant"),
          "interpretation" => interpret_cohens_d(comp.effect_size)
        }
      end)

    VegaLite.new(width: 600, height: 400, title: "Effect Sizes (Cohen's d) by Comparison")
    |> VegaLite.data_from_values(data)
    |> VegaLite.mark(:bar, tooltip: true)
    |> VegaLite.encode_field(:x, "comparison",
      type: :nominal,
      title: "Comparison",
      axis: [label_angle: -45]
    )
    |> VegaLite.encode_field(:y, "effect_size",
      type: :quantitative,
      title: "Effect Size (Cohen's d)",
      scale: [zero: true]
    )
    |> VegaLite.encode_field(:color, "significant",
      type: :nominal,
      scale: [
        domain: ["Significant", "Not Significant"],
        range: ["#10b981", "#ef4444"]
      ],
      legend: [title: "Significance"]
    )
    |> VegaLite.encode(:tooltip, [
      [field: "comparison", type: :nominal, title: "Comparison"],
      [field: "effect_size", type: :quantitative, title: "Effect Size", format: ".3f"],
      [field: "interpretation", type: :nominal, title: "Interpretation"],
      [field: "significant", type: :nominal, title: "Significant?"]
    ])
    |> Kino.VegaLite.new()
  end

  defp interpret_eta_squared(eta) when eta < 0.01, do: "Small effect"
  defp interpret_eta_squared(eta) when eta < 0.06, do: "Medium effect"
  defp interpret_eta_squared(_), do: "Large effect"

  defp interpret_cohens_d(d) when d < 0.2, do: "Negligible effect"
  defp interpret_cohens_d(d) when d < 0.5, do: "Small effect"
  defp interpret_cohens_d(d) when d < 0.8, do: "Medium effect"
  defp interpret_cohens_d(_), do: "Large effect"

  defp format_number(num) when is_float(num) do
    :erlang.float_to_binary(num, decimals: 2)
  end

  defp format_number(num), do: to_string(num)

  defp format_scientific(num) when num < 0.001 do
    :io_lib.format("~.2e", [num]) |> to_string()
  end

  defp format_scientific(num) do
    :erlang.float_to_binary(num, decimals: 5)
  end
end
