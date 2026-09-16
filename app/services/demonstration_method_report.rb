# Uses the same target population for both the FCO summary and VRP drill-down.
class DemonstrationMethodReport
  # View List (per-JJ drill-down) columns. Each training method has a record Count
  # and a distinct Farmer count; "Target Farmer Count" is village-deduped per JJ.
  HEADERS = [
    "fco_id", "fco_name", "Cluster Coordinator", "vrp_id", "VRP Name",
    "OPG Target / Done", "General Training/Meeting", "Input Demo INM",
    "Input Demo PM", "FFS", "Status"
  ].freeze

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
      raw_rows = connection.select_all(<<~SQL).to_a
        WITH scoped_targets AS (
          #{scope.to_sql}
        ), village_target AS (
          SELECT
            t.fco_id, t.fco_name, t.vrp_id, t.village_id,
            MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target,
            MAX(COALESCE(t.week_wise_opg_target, 0)) AS general_training_target,
            MAX(COALESCE(t.input_demo_inm_target, 0)) AS input_demo_inm_target,
            MAX(COALESCE(t.input_demo_pm_target, 0)) AS input_demo_pm_target,
            MAX(COALESCE(t.ffs_target, 0)) AS ffs_target
          FROM scoped_targets t
          GROUP BY t.fco_id, t.fco_name, t.vrp_id, t.village_id
        ), vrp_target AS (
          SELECT
            fco_id, fco_name, vrp_id,
            SUM(opg_training_target) AS opg_training_target,
            SUM(general_training_target) AS general_training_target,
            SUM(input_demo_inm_target) AS input_demo_inm_target,
            SUM(input_demo_pm_target) AS input_demo_pm_target,
            SUM(ffs_target) AS ffs_target
          FROM village_target
          GROUP BY fco_id, fco_name, vrp_id
        ), entry_data AS (
          SELECT
            TRIM(mr.data::jsonb ->> 'created_by_id') AS vrp_id,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'general training/meeting') AS general_training_done,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo inm') AS input_demo_inm_done,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo pm') AS input_demo_pm_done,
            COUNT(*) FILTER (WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'ffs') AS ffs_done
          FROM module_records mr
          WHERE mr.module_slug = 'training-form' AND #{month_filter}
          GROUP BY TRIM(mr.data::jsonb ->> 'created_by_id')
        )
        SELECT
          vt.fco_id, vt.fco_name,
          COALESCE(v.cluster_incharge, '') AS "Cluster Coordinator",
          vt.vrp_id,
          COALESCE(v.name, '') AS "VRP Name",
          vt.general_training_target AS gen_target,
          COALESCE(ed.general_training_done, 0) AS gen_done,
          vt.input_demo_inm_target AS inm_target,
          COALESCE(ed.input_demo_inm_done, 0) AS inm_done,
          vt.input_demo_pm_target AS pm_target,
          COALESCE(ed.input_demo_pm_done, 0) AS pm_done,
          vt.ffs_target AS ffs_target,
          COALESCE(ed.ffs_done, 0) AS ffs_done
        FROM vrp_target vt
        LEFT JOIN vrps v ON v.id::text = vt.vrp_id::text
        LEFT JOIN entry_data ed ON ed.vrp_id = vt.vrp_id::text
        ORDER BY vt.fco_id, "Cluster Coordinator", vt.vrp_id
      SQL

      raw_rows.map do |r|
        gen_t = r["gen_target"].to_i
        gen_d = r["gen_done"].to_i
        inm_t = r["inm_target"].to_i
        inm_d = r["inm_done"].to_i
        pm_t  = r["pm_target"].to_i
        pm_d  = r["pm_done"].to_i
        ffs_t = r["ffs_target"].to_i
        ffs_d = r["ffs_done"].to_i

        tot_t = gen_t + inm_t + pm_t + ffs_t
        tot_d = gen_d + inm_d + pm_d + ffs_d

        status = if tot_t.positive? && tot_d.zero?
          "Red"
        elsif tot_t.positive? && tot_d > 0 && tot_d < tot_t
          "Yellow"
        else
          "Green"
        end

        {
          "fco_id"                  => r["fco_id"],
          "fco_name"                => r["fco_name"],
          "Cluster Coordinator"     => r["Cluster Coordinator"],
          "vrp_id"                  => r["vrp_id"],
          "VRP Name"                => r["VRP Name"],
          "OPG Target / Done"       => "#{tot_t} / #{tot_d}",
          "General Training/Meeting"=> "#{gen_t} / #{gen_d}",
          "Input Demo INM"          => "#{inm_t} / #{inm_d}",
          "Input Demo PM"           => "#{pm_t} / #{pm_d}",
          "FFS"                     => "#{ffs_t} / #{ffs_d}",
          "Status"                  => status
        }
      end
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
          SELECT t.fco_id, t.fco_name, t.village_id,
            MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target,
            MAX(COALESCE(t.week_wise_opg_target, 0)) AS general_training_target,
            MAX(COALESCE(t.input_demo_inm_target, 0)) AS input_demo_inm_target,
            MAX(COALESCE(t.input_demo_pm_target, 0)) AS input_demo_pm_target,
            MAX(COALESCE(t.ffs_target, 0)) AS ffs_target
          FROM scoped_targets t
          GROUP BY t.fco_id, t.fco_name, t.village_id
        ), fco_target AS (
          SELECT fco_id, fco_name,
            SUM(opg_training_target) AS opg_training_target,
            SUM(general_training_target) AS general_training_target,
            SUM(input_demo_inm_target) AS input_demo_inm_target,
            SUM(input_demo_pm_target) AS input_demo_pm_target,
            SUM(ffs_target) AS ffs_target
          FROM village_target GROUP BY fco_id, fco_name
        ), vrp_fco AS (
          SELECT DISTINCT t.fco_id, t.fco_name, t.vrp_id
          FROM scoped_targets t
        ), training_entries AS MATERIALIZED (
          SELECT TRIM(mr.data::jsonb ->> 'created_by_id') AS vrp_id,
            LOWER(TRIM(mr.data::jsonb ->> 'training_method')) AS training_method
          FROM module_records mr
          WHERE mr.module_slug = 'training-form' AND #{month_filter}
            AND TRIM(mr.data::jsonb ->> 'created_by_id') IN (
              SELECT DISTINCT vf.vrp_id::text FROM vrp_fco vf
            )
        ), entry_data AS (
          SELECT vf.fco_id, vf.fco_name,
            COUNT(*) FILTER (WHERE te.training_method = 'general training/meeting') AS general_training_meeting,
            COUNT(*) FILTER (WHERE te.training_method = 'input demo inm') AS input_demo_inm,
            COUNT(*) FILTER (WHERE te.training_method = 'input demo pm') AS input_demo_pm,
            COUNT(*) FILTER (WHERE te.training_method = 'ffs') AS ffs
          FROM training_entries te
          INNER JOIN vrp_fco vf
            ON vf.vrp_id::text = te.vrp_id
          GROUP BY vf.fco_id, vf.fco_name
        )
        SELECT ft.fco_id, ft.fco_name,
          ft.opg_training_target AS "OPG Target",
          ft.general_training_target AS "General Training/Meeting Target",
          COALESCE(ed.general_training_meeting, 0) AS "General Training/Meeting",
          COALESCE(ed.general_training_meeting, 0) AS "General Training/Meeting Done",
          ft.input_demo_inm_target AS "Input Demo INM Target",
          COALESCE(ed.input_demo_inm, 0) AS "Input Demo INM",
          COALESCE(ed.input_demo_inm, 0) AS "Input Demo INM Done",
          ft.input_demo_pm_target AS "Input Demo PM Target",
          COALESCE(ed.input_demo_pm, 0) AS "Input Demo PM",
          COALESCE(ed.input_demo_pm, 0) AS "Input Demo PM Done",
          ft.ffs_target AS "FFS Target",
          COALESCE(ed.ffs, 0) AS "FFS",
          COALESCE(ed.ffs, 0) AS "FFS Done"
        FROM fco_target ft
        LEFT JOIN entry_data ed ON ed.fco_id::text = ft.fco_id::text
        ORDER BY ft.fco_id
      SQL
    end
  end
end
