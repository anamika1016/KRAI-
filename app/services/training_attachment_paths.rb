require "uri"

class TrainingAttachmentPaths
  FIELDS = %w[training_register_upload training_photo_upload_with_geo_tag
    photo_front_view photo_back_view photo_close_up_view photo_long_shot].freeze

  def self.for_record(record)
    new.for_record(record)
  end

  def initialize
    @resolved_paths = {}
  end

  def for_record(record)
    FIELDS.flat_map do |field|
      value = record.data[field]
      value = value.presence || record.data["photo_close-up_view"] if field == "photo_close_up_view"
      ModuleUploadPaths.call(value).filter_map do |url|
        @resolved_paths.fetch(url) do
          @resolved_paths[url] = resolve(url)
        end
      end
    end.uniq
  end

  private

  def resolve(url)
    @root ||= Rails.root.join("public", "uploads", "module_records").realpath
    path = URI.parse(url).path.to_s
    return unless path.start_with?("/uploads/module_records/")

    file = Rails.root.join("public", path.delete_prefix("/")).realpath
    file if file.file? && file.to_s.start_with?("#{@root}/")
  rescue URI::InvalidURIError, Errno::ENOENT, Errno::EACCES
    nil
  end
end
