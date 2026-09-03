// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "layout"

if (window.Turbo) {
  Turbo.config.drive.progressBarDelay = 2147483647;
}
