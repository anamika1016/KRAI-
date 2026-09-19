# Demonstration Method targets are de-duplicated per village, then summarized by FCO.
class DemonstrationMethodReport
  HEADERS = ["fco_id", "fco_name", "OPG Target", "CC Target", "Total Target / Done", "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].freeze

  def initialize(targets:, month: "August")
    @target_ids = targets.is_a?(ActiveRecord::Relation) && !targets.loaded? ? targets.pluck(:id).uniq : Array(targets).map(&:id).uniq
    @month = month.to_s.strip.downcase
  end

  def rows
    @rows ||= summary.map do |row|
      { "fco_id" => row["fco_id"], "fco_name" => row["fco_name"], "OPG Target" => row["OPG Target"].to_i, "CC Target" => row["CC Target"].to_i,
        "Total Target / Done" => pair(row, "Total Target", "Total Done"),
        "General Training/Meeting" => pair(row, "General Training/Meeting Target", "General Training/Meeting Done"),
        "Input Demo INM" => pair(row, "Input Demo INM Target", "Input Demo INM Done"),
        "Input Demo PM" => pair(row, "Input Demo PM Target", "Input Demo PM Done"), "FFS" => pair(row, "FFS Target", "FFS Done") }
    end
  end

  def summary
    @summary ||= begin
      connection = TargetMapping.connection
      # This report deliberately follows the supplied query: its population is
      # all target mappings for the selected month, not the dashboard's
      # activity/VRP-filtered target collection.
      scope = TargetMapping.all
      scope = scope.where("LOWER(TRIM(month_name)) = ?", @month) unless @month.blank? || @month == "all"
      month_filter = @month.blank? || @month == "all" ? "TRUE" : "LOWER(TRIM(mr.data::jsonb ->> 'month')) = #{connection.quote(@month)}"
      connection.select_all(<<~SQL).to_a
        WITH village_target AS (
          SELECT t.fco_id, t.fco_name, t.village_id, MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target, MAX(COALESCE(t.cc_target, 0)) AS cc_target,
            MAX(COALESCE(t.week_wise_opg_target, 0)) AS general_training_target, MAX(COALESCE(t.input_demo_inm_target, 0)) AS input_demo_inm_target,
            MAX(COALESCE(t.input_demo_pm_target, 0)) AS input_demo_pm_target, MAX(COALESCE(t.ffs_target, 0)) AS ffs_target
          FROM (#{scope.to_sql}) t GROUP BY t.fco_id, t.fco_name, t.village_id
        ), fco_target AS (
          SELECT fco_id, fco_name, SUM(opg_training_target) AS opg_training_target, SUM(cc_target) AS cc_target, SUM(general_training_target) AS general_training_target,
            SUM(input_demo_inm_target) AS input_demo_inm_target, SUM(input_demo_pm_target) AS input_demo_pm_target, SUM(ffs_target) AS ffs_target
          FROM village_target GROUP BY fco_id, fco_name
        ), vrp_fco AS (
          SELECT DISTINCT t.fco_id, t.fco_name, t.vrp_id FROM (#{scope.to_sql}) t
        ), entry_data AS (
          SELECT vf.fco_id, vf.fco_name,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'general training/meeting') AS general_training_done,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo inm') AS input_demo_inm_done,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo pm') AS input_demo_pm_done,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'ffs') AS ffs_done
          FROM module_records mr INNER JOIN vrp_fco vf ON vf.vrp_id::text = TRIM(mr.data::jsonb ->> 'created_by_id')
          WHERE mr.module_slug = 'training-form' AND #{month_filter} GROUP BY vf.fco_id, vf.fco_name
        )
        SELECT ft.fco_id, ft.fco_name, COALESCE(ft.opg_training_target, 0) AS "OPG Target", COALESCE(ft.cc_target, 0) AS "CC Target",
          COALESCE(ft.general_training_target, 0) AS "General Training/Meeting Target", COALESCE(ed.general_training_done, 0) AS "General Training/Meeting Done",
          COALESCE(ft.input_demo_inm_target, 0) AS "Input Demo INM Target", COALESCE(ed.input_demo_inm_done, 0) AS "Input Demo INM Done",
          COALESCE(ft.input_demo_pm_target, 0) AS "Input Demo PM Target", COALESCE(ed.input_demo_pm_done, 0) AS "Input Demo PM Done",
          COALESCE(ft.ffs_target, 0) AS "FFS Target", COALESCE(ed.ffs_done, 0) AS "FFS Done",
          COALESCE(ft.general_training_target, 0) + COALESCE(ft.input_demo_inm_target, 0) + COALESCE(ft.input_demo_pm_target, 0) + COALESCE(ft.ffs_target, 0) AS "Total Target",
          COALESCE(ed.general_training_done, 0) + COALESCE(ed.input_demo_inm_done, 0) + COALESCE(ed.input_demo_pm_done, 0) + COALESCE(ed.ffs_done, 0) AS "Total Done"
        FROM fco_target ft LEFT JOIN entry_data ed ON ed.fco_id::text = ft.fco_id::text ORDER BY ft.fco_id
      SQL
    end
  end

  private

  def pair(row, target, done)
    "#{row[target].to_i} / #{row[done].to_i}"
  end
end
