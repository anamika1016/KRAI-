# Uses the same target population for both the FCO summary and VRP drill-down.
class DemonstrationMethodReport
  # View List (per-JJ drill-down) columns. Each training method has a record Count
  # and a distinct Farmer count; "Target Farmer Count" is village-deduped per JJ.
  HEADERS = ["fco_id", "fco_name", "vrp_id", "VRP Name", "Target Farmer Count", "OPG Target",
    "General Training/Meeting Count", "General Training/Meeting Farmer",
    "Input Demo INM Count", "Input Demo INM Farmer",
    "Input Demo PM Count", "Input Demo PM Farmer",
    "FFS Count", "FFS Farmer"].freeze
  # Dashboard summary-card metrics (FCO level). Kept separate from HEADERS because
  # the summary reports one count per method, not the Count/Farmer split above.
  METRICS = ["OPG Target", "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].freeze

  def initialize(targets:, month: "August")
    @target_ids = Array(targets).map(&:id).uniq
    @month = month.to_s.strip.downcase
  end

  def rows
    @rows ||= begin
      connection = TargetMapping.connection
      scope = TargetMapping.where(id: @target_ids)
      scope = scope.where("LOWER(TRIM(month_name)) = ?", @month) unless @month.blank? || @month == "all"
      month_filter = if @month.blank? || @month == "all"
        "TRUE"
      else
        "LOWER(TRIM(mr.data::jsonb ->> 'month')) = #{connection.quote(@month)}"
      end
      connection.select_all(<<~SQL).to_a
        WITH scoped_targets AS (
          #{scope.to_sql}
        ), village_target AS (
          -- Ek village ka OPG target aur farmer count sirf ek baar (village_id ke hisaab se MAX)
          SELECT t.fco_id, t.fco_name, t.vrp_id, t.village_id,
            MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target,
            MAX(COALESCE(t.farmer_count, 0)) AS farmer_count
          FROM scoped_targets t
          GROUP BY t.fco_id, t.fco_name, t.vrp_id, t.village_id
        ), target_data AS (
          SELECT fco_id, fco_name, vrp_id,
            SUM(opg_training_target) AS opg_training_target,
            SUM(farmer_count) AS farmer_count
          FROM village_target
          GROUP BY fco_id, fco_name, vrp_id
        ), entry_data AS (
          SELECT x.vrp_id,
            COUNT(DISTINCT x.record_id) FILTER (WHERE x.training_method = 'general training/meeting') AS gtm_count,
            COUNT(DISTINCT x.farmer_id) FILTER (WHERE x.training_method = 'general training/meeting') AS gtm_farmer,
            COUNT(DISTINCT x.record_id) FILTER (WHERE x.training_method = 'input demo inm') AS inm_count,
            COUNT(DISTINCT x.farmer_id) FILTER (WHERE x.training_method = 'input demo inm') AS inm_farmer,
            COUNT(DISTINCT x.record_id) FILTER (WHERE x.training_method = 'input demo pm') AS pm_count,
            COUNT(DISTINCT x.farmer_id) FILTER (WHERE x.training_method = 'input demo pm') AS pm_farmer,
            COUNT(DISTINCT x.record_id) FILTER (WHERE x.training_method = 'ffs') AS ffs_count,
            COUNT(DISTINCT x.farmer_id) FILTER (WHERE x.training_method = 'ffs') AS ffs_farmer
          FROM (
            SELECT mr.id AS record_id,
              TRIM(mr.data::jsonb ->> 'created_by_id') AS vrp_id,
              LOWER(TRIM(mr.data::jsonb ->> 'training_method')) AS training_method,
              sf.farmer_id
            FROM module_records mr
            LEFT JOIN LATERAL jsonb_array_elements_text(
              COALESCE(mr.data::jsonb -> 'selected_farmer_ids', '[]'::jsonb)
            ) AS sf(farmer_id) ON TRUE
            WHERE mr.module_slug = 'training-form' AND #{month_filter}
          ) x
          GROUP BY x.vrp_id
        )
        SELECT t.fco_id, t.fco_name, t.vrp_id, v.name AS "VRP Name",
          t.farmer_count AS "Target Farmer Count",
          t.opg_training_target AS "OPG Target",
          COALESCE(e.gtm_count, 0) AS "General Training/Meeting Count",
          COALESCE(e.gtm_farmer, 0) AS "General Training/Meeting Farmer",
          COALESCE(e.inm_count, 0) AS "Input Demo INM Count",
          COALESCE(e.inm_farmer, 0) AS "Input Demo INM Farmer",
          COALESCE(e.pm_count, 0) AS "Input Demo PM Count",
          COALESCE(e.pm_farmer, 0) AS "Input Demo PM Farmer",
          COALESCE(e.ffs_count, 0) AS "FFS Count",
          COALESCE(e.ffs_farmer, 0) AS "FFS Farmer"
        FROM target_data t
        LEFT JOIN vrps v ON v.id::text = t.vrp_id::text
        LEFT JOIN entry_data e ON e.vrp_id = t.vrp_id::text
        ORDER BY t.fco_id, v.name
      SQL
    end
  end

  def summary
    @summary ||= begin
      connection = TargetMapping.connection
      scope = TargetMapping.where(id: @target_ids)
      scope = scope.where("LOWER(TRIM(month_name)) = ?", @month) unless @month.blank? || @month == "all"
      month_filter = @month.blank? || @month == "all" ? "TRUE" : "LOWER(TRIM(mr.data::jsonb ->> 'month')) = #{connection.quote(@month)}"
      connection.select_all(<<~SQL).to_a
        WITH scoped_targets AS (
          #{scope.to_sql}
        ), village_target AS (
          -- Ek village ka OPG target sirf ek baar (village_id ke hisaab se MAX)
          SELECT t.fco_id, t.fco_name, t.village_id,
            MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target
          FROM scoped_targets t
          GROUP BY t.fco_id, t.fco_name, t.village_id
        ), fco_target AS (
          SELECT fco_id, fco_name, SUM(opg_training_target) AS opg_training_target
          FROM village_target GROUP BY fco_id, fco_name
        ), vrp_fco AS (
          SELECT DISTINCT t.fco_id, t.fco_name, t.vrp_id
          FROM scoped_targets t
        ), entry_data AS (
          SELECT vf.fco_id, vf.fco_name,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'general training/meeting') AS general_training_meeting,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo inm') AS input_demo_inm,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo pm') AS input_demo_pm,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'ffs') AS ffs
          FROM module_records mr
          INNER JOIN vrp_fco vf
            ON vf.vrp_id::text = TRIM(mr.data::jsonb ->> 'created_by_id')
          WHERE mr.module_slug = 'training-form' AND #{month_filter}
          GROUP BY vf.fco_id, vf.fco_name
        )
        SELECT ft.fco_id, ft.fco_name, ft.opg_training_target AS "OPG Target",
          COALESCE(ed.general_training_meeting, 0) AS "General Training/Meeting",
          COALESCE(ed.input_demo_inm, 0) AS "Input Demo INM",
          COALESCE(ed.input_demo_pm, 0) AS "Input Demo PM",
          COALESCE(ed.ffs, 0) AS "FFS"
        FROM fco_target ft
        LEFT JOIN entry_data ed ON ed.fco_id::text = ft.fco_id::text
        ORDER BY ft.fco_id
      SQL
    end
  end
end
