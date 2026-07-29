# frozen_string_literal: true

module Api
  module V1
    class JeevikaJankarPaymentsController < BaseController
      BILL_SLUG = "jeevika-jankar-bill-process".freeze

      def bills
        records = bill_records.select { |record| calculator.send(:jeevika_jankar_bill_record_visible?, record) }
        all_rows = records.map { |record| bill_payload_for(record) }
        rows = filter_month(all_rows)

        render json: {
          success: true,
          message: "Jeevika Jankar bill list fetched successfully.",
          months: month_options(all_rows),
          bills: rows,
          count: rows.size
        }, status: :ok
      end

      def payments
        return payment_access_denied unless payment_list_user?

        months = calculator.send(:jeevika_bill_payment_month_options, bill_records)
        month = selected_month.presence || months.first
        records = bill_records.select do |record|
          calculator.send(:jeevika_bill_final_approved?, record) &&
            (month.blank? || same_text?(record.data["bill_month"], month))
        end
        rows = records.map { |record| payment_payload_for(record) }

        render json: {
          success: true,
          message: "Jeevika Jankar payment list fetched successfully.",
          months: months,
          selected_month: month,
          payments: rows,
          count: rows.size
        }, status: :ok
      end

      def payment_details
        return payment_access_denied unless payment_list_user?

        rows = calculator.send(:jeevika_payment_selectable_rows, bill_records)
        approval_dates = calculator.send(:jeevika_payment_bill_date_options, bill_records)
        rows = rows.select { |row| row[:approval_date].to_s == params[:approval_date].to_s } if params[:approval_date].present?

        render json: {
          success: true,
          message: "Jeevika Jankar unpaid payment details fetched successfully.",
          approval_dates: approval_dates,
          selected_approval_date: params[:approval_date],
          transaction_types: ModulesController::JEEVIKA_PAYMENT_TRANSACTION_TYPES,
          payment_amount_per_bill: ModulesController::JEEVIKA_JANKAR_BILL_FIXED_TOTAL,
          selectable_bills: rows,
          count: rows.size
        }, status: :ok
      end

      def completed_payments
        return payment_access_denied unless payment_list_user?

        all_rows = calculator.send(:jeevika_completed_payment_rows).map { |row| completed_payment_payload(row) }
        months = calculator.send(:jeevika_completed_payment_month_options, all_rows)
        month = selected_month.presence || months.first
        rows = all_rows
        rows = rows.select { |row| same_text?(row[:bill_month], month) } if month.present?
        dates = calculator.send(:jeevika_completed_payment_date_options, all_rows, month)
        rows = rows.select { |row| row[:approval_date].to_s == params[:approval_date].to_s } if params[:approval_date].present?

        render json: {
          success: true,
          message: "Jeevika Jankar completed payment list fetched successfully.",
          months: months,
          approval_dates: dates,
          selected_month: month,
          selected_approval_date: params[:approval_date],
          completed_payments: rows,
          count: rows.size
        }, status: :ok
      end

      private

      def calculator
        @calculator ||= ModulesController.new.tap do |controller|
          controller.instance_variable_set(:@current_app_user, current_api_user_payload)
        end
      end

      def bill_records
        @bill_records ||= ModuleRecord.where(module_slug: BILL_SLUG).order(created_at: :desc, id: :desc).to_a
      end

      def payment_list_user?
        calculator.send(:jeevika_jankar_payment_list_user?)
      end

      def payment_access_denied
        render json: { success: false, message: "You are not allowed to access payment records." }, status: :forbidden
      end

      def selected_month
        params[:month].presence || params[:payment_month].presence
      end

      def filter_month(rows)
        return rows if selected_month.blank?

        rows.select { |row| same_text?(row[:bill_month], selected_month) }
      end

      def month_options(rows)
        rows.filter_map { |row| row[:bill_month].to_s.strip.presence }
          .reject { |month| month == "-" }.uniq
      end

      def bill_payload_for(record)
        data = record.data
        summary = calculator.send(:jeevika_bill_summary, record)
        history = calculator.send(:jeevika_bill_approval_history, record)
        vrp_label = data["select_vrp_name"].presence || calculator.send(:jeevika_jankar_vrp_label, data["select_vrp"])

        {
          id: record.id,
          bill_id: record.id,
          vrp_id: data["select_vrp"],
          name: calculator.send(:jeevika_jankar_display_name, vrp_label),
          financial_year: data["financial_year"].presence || "-",
          bill_month: data["bill_month"].presence || "-",
          activity_groups: summary[:activity_groups].presence || "-",
          activity_names: summary[:activity_names].presence || "-",
          target: data["total_target"].presence || "0",
          achievement: data["total_achievement"].presence || "0",
          amount: calculator.send(:jeevika_jankar_bill_total_payment, record),
          status: calculator.send(:jeevika_bill_status_label, record),
          status_class: calculator.send(:jeevika_bill_status_class, record),
          record_state: data["record_state"].presence || "Active",
          current_approver: calculator.send(:jeevika_bill_current_approver?, record),
          approval_remarks: calculator.send(:bill_approval_remarks_text, history)
        }
      end

      def payment_payload_for(record)
        bank_row = calculator.send(:jeevika_bill_bank_rows, record).first || {}
        vrp = calculator.send(:jeevika_bill_vrp, record)
        payload = bill_payload_for(record).merge(
          bank_name: bank_row[:bank_name].presence || "-",
          ifsc_code: bank_row[:ifsc_code].presence || "-",
          account_number: bank_row[:account_number].presence || "-"
        )
        attachment = vrp&.bank_passbook_upload
        payload[:passbook_url] = attachment_url(attachment) if attachment&.attached?
        payload
      end

      def completed_payment_payload(row)
        row.merge(
          transaction_file: public_file_url(row[:transaction_file]),
          excel_file: public_file_url(row[:excel_file])
        )
      end

      def attachment_url(attachment)
        Rails.application.routes.url_helpers.rails_blob_url(attachment, host: request.base_url)
      end

      def public_file_url(value)
        return if value.blank?
        return value if value.to_s.match?(/\Ahttps?:\/\//i)

        "#{request.base_url}#{value.to_s.start_with?("/") ? value : "/#{value}"}"
      end

      def same_text?(left, right)
        left.to_s.strip.casecmp(right.to_s.strip).zero?
      end
    end
  end
end
