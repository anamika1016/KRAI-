require "minitest/autorun"
require "json"
require_relative "../app/services/module_upload_paths"

class ModuleUploadPathsUnitTest < Minitest::Test
  def test_json_photo_array
    assert_equal ["/uploads/a.jpg", "/uploads/b.jpg"], ModuleUploadPaths.call('["/uploads/a.jpg","/uploads/b.jpg"]')
  end

  def test_sql_aggregated_arrays
    assert_equal ["/uploads/a.jpg", "/uploads/b.jpg"], ModuleUploadPaths.call('["/uploads/a.jpg"], ["/uploads/b.jpg"]')
  end

  def test_nested_and_legacy_paths
    assert_equal ["/uploads/a.jpg", "https://example.com/b.jpg"], ModuleUploadPaths.call(['uploads/a.jpg', { photo: '["https://example.com/b.jpg"]' }, '/uploads/a.jpg'])
    assert_equal ["/uploads/a.jpg", "/uploads/b.jpg"], ModuleUploadPaths.call('/uploads/a.jpg, /uploads/b.jpg')
  end

  def test_rendered_links_point_to_each_image
    html = ApplicationController.render(partial: "modules/training_participation_uploads",
      locals: { urls: '["/uploads/a.jpg", "/uploads/b.jpg"]', label: "training photo" })
    assert_includes html, 'href="/uploads/a.jpg"'
    assert_includes html, 'href="/uploads/b.jpg"'
    refute_includes html, 'href="['
  end

  def test_screenshot_photo_becomes_an_absolute_upload_link
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.request.host = "krai.ploughmanagro.com"
    controller.request.set_header("HTTPS", "on")
    path = "/uploads/module_records/1788796979-7c240b56-1000014852.jpg"
    urls = controller.send(:module_upload_public_urls, [path].to_json)
    assert_equal ["https://krai.ploughmanagro.com#{path}"], urls
    html = ApplicationController.render(partial: "modules/training_participation_uploads",
      locals: { urls: urls, label: "training photo" })
    assert_includes html, "href=\"#{urls.first}\""
    refute_includes html, "/dashboard/"
  end

  def test_empty_malformed_and_unsafe_values
    [nil, '', '-', '[]', '["/uploads/a.jpg"', 'javascript:alert(1)'].each do |value|
      assert_empty ModuleUploadPaths.call(value)
    end
  end
end
