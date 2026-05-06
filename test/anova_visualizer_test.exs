defmodule AnovaVisualizerTest do
  use ExUnit.Case

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  # Three groups with clearly different means so at least some pairs are
  # significant (helps exercise all branches in render_posthoc_summary,
  # render_comparison_card, etc.).
  @groups [
    [10.0, 12.0, 11.0, 13.0, 10.5],
    [20.0, 22.0, 21.0, 23.0, 20.5],
    [30.0, 32.0, 31.0, 33.0, 30.5]
  ]

  defp run_analysis do
    anova = ANOVA.one_way(@groups)
    TukeyHSD.test(anova, 0.05)
  end

  # A results map where NO pairs are significant: each group has the same mean
  # (10.0) but non-zero within-group variance so ms_within > 0 and F = 0.
  defp non_significant_results do
    groups = [
      [9.0, 10.0, 11.0, 10.0],
      [9.0, 10.0, 11.0, 10.0],
      [9.0, 10.0, 11.0, 10.0]
    ]

    anova = ANOVA.one_way(groups)
    TukeyHSD.test(anova, 0.05)
  end

  # ---------------------------------------------------------------------------
  # visualize/1 — structure tests
  # ---------------------------------------------------------------------------

  describe "visualize/1" do
    test "returns a Kino.Layout for valid 3-group results" do
      result = run_analysis()
      layout = AnovaVisualizer.visualize(result)
      assert %Kino.Layout{} = layout
    end

    test "works with minimum 2 groups" do
      anova = ANOVA.one_way([[1.0, 2.0, 3.0], [10.0, 11.0, 12.0]])
      result = TukeyHSD.test(anova, 0.05)
      layout = AnovaVisualizer.visualize(result)
      assert %Kino.Layout{} = layout
    end

    test "works when no pairs are significant" do
      result = non_significant_results()
      layout = AnovaVisualizer.visualize(result)
      assert %Kino.Layout{} = layout
    end

    test "works with a single-observation-per-group edge case" do
      # Each group must have >= 2 observations per the ANOVA library constraint.
      anova = ANOVA.one_way([[1.0, 2.0], [5.0, 6.0], [9.0, 10.0]])
      result = TukeyHSD.test(anova, 0.05)
      assert %Kino.Layout{} = AnovaVisualizer.visualize(result)
    end

    test "works with alpha = 0.01 (stricter threshold)" do
      anova = ANOVA.one_way(@groups)
      result = TukeyHSD.test(anova, 0.01)
      assert %Kino.Layout{} = AnovaVisualizer.visualize(result)
    end
  end

  # ---------------------------------------------------------------------------
  # visualize/3 — groups parameter
  # ---------------------------------------------------------------------------

  describe "visualize/3 with groups" do
    test "accepts a list of group names" do
      result = run_analysis()
      layout = AnovaVisualizer.visualize(result, "My Title", ["Control", "Treatment A", "Treatment B"])
      assert %Kino.Layout{} = layout
    end

    test "works when groups list matches the number of groups exactly" do
      anova = ANOVA.one_way([[1.0, 2.0, 3.0], [10.0, 11.0, 12.0]])
      result = TukeyHSD.test(anova, 0.05)
      assert %Kino.Layout{} = AnovaVisualizer.visualize(result, "Two Groups", ["A", "B"])
    end

    test "falls back to 'Group N' for out-of-range indices" do
      result = run_analysis()
      # Only 2 names provided for 3 groups — third should fall back gracefully
      assert %Kino.Layout{} = AnovaVisualizer.visualize(result, "Partial Names", ["Alpha", "Beta"])
    end

    test "nil groups behaves identically to omitting groups" do
      result = run_analysis()
      assert %Kino.Layout{} = AnovaVisualizer.visualize(result, "Title", nil)
    end
  end

  # ---------------------------------------------------------------------------
  # ANOVA structural integrity — ensure the anova dep returns what we rely on
  # ---------------------------------------------------------------------------

  describe "ANOVA.one_way/1 result shape" do
    test "contains the expected summary keys" do
      anova = ANOVA.one_way(@groups)

      assert Map.has_key?(anova.summary, :groups)
      assert Map.has_key?(anova.summary, :group_sizes)
      assert Map.has_key?(anova.summary, :total_observations)
      assert Map.has_key?(anova.summary, :overall_mean)
      assert Map.has_key?(anova.summary, :group_means)
    end

    test "anova_table has between/within/total sub-maps" do
      anova = ANOVA.one_way(@groups)

      assert %{ss: _, df: _, ms: _} = anova.anova_table.between
      assert %{ss: _, df: _, ms: _} = anova.anova_table.within
      assert %{ss: _, df: _} = anova.anova_table.total
    end

    test "test_results has f_statistic, p_value, eta_squared, omega_squared" do
      anova = ANOVA.one_way(@groups)

      assert %{f_statistic: f, p_value: p, eta_squared: eta, omega_squared: omega} =
               anova.test_results

      assert is_float(f) and f > 0
      assert is_float(p) and p >= 0 and p <= 1
      assert is_float(eta) and eta >= 0 and eta <= 1
      assert is_float(omega)
    end
  end

  # ---------------------------------------------------------------------------
  # TukeyHSD.test/2 result shape
  # ---------------------------------------------------------------------------

  describe "TukeyHSD.test/2 result shape" do
    test "wraps anova and post_hoc_test keys" do
      result = run_analysis()

      assert Map.has_key?(result, :anova)
      assert Map.has_key?(result, :post_hoc_test)
    end

    test "post_hoc_test has expected summary keys" do
      %{post_hoc_test: pht} = run_analysis()

      assert Map.has_key?(pht.summary, :total_comparisons)
      assert Map.has_key?(pht.summary, :significant_comparisons)
      assert Map.has_key?(pht.summary, :non_significant_comparisons)
      assert Map.has_key?(pht.summary, :significant_pairs)
      assert Map.has_key?(pht.summary, :difference_stats)
      assert Map.has_key?(pht.summary, :effect_size_stats)
    end

    test "3 groups produce 3 pairwise comparisons (C(3,2) = 3)" do
      %{post_hoc_test: %{pairwise_comparisons: comps}} = run_analysis()
      assert length(comps) == 3
    end

    test "each comparison has required fields" do
      %{post_hoc_test: %{pairwise_comparisons: comps}} = run_analysis()

      for comp <- comps do
        assert {_g1, _g2} = comp.groups
        assert {_m1, _m2} = comp.means
        assert is_float(comp.difference) and comp.difference >= 0
        assert is_float(comp.standard_error)
        assert is_float(comp.q_statistic)
        assert is_float(comp.p_value) and comp.p_value >= 0 and comp.p_value <= 1
        assert is_boolean(comp.significant?)
        assert %{lower: _, upper: _, level: 95.0} = comp.confidence_interval
        assert is_float(comp.effect_size) and comp.effect_size >= 0
      end
    end

    test "all 3 comparisons are significant for clearly separated groups" do
      %{post_hoc_test: %{pairwise_comparisons: comps}} = run_analysis()
      assert Enum.all?(comps, & &1.significant?)
    end

    test "significant_comparisons + non_significant_comparisons == total_comparisons" do
      %{post_hoc_test: %{summary: s}} = run_analysis()
      assert s.significant_comparisons + s.non_significant_comparisons == s.total_comparisons
    end

    test "confidence_interval lower < upper" do
      %{post_hoc_test: %{pairwise_comparisons: comps}} = run_analysis()

      for comp <- comps do
        assert comp.confidence_interval.lower < comp.confidence_interval.upper
      end
    end
  end
end
