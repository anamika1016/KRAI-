require "test_helper"
require "timeout"

class DashboardCacheFillTest < ActiveSupport::TestCase
  test "parallel cache misses calculate once and version changes recalculate" do
    cache = ActiveSupport::Cache::MemoryStore.new
    calls = 0
    ready = Queue.new
    release = Queue.new
    fetch = lambda do |version|
      DashboardCacheFill.synchronize('same-user-same-filters') do
        cache.fetch(['dashboard', version]) do
          calls += 1
          if version == 1
            ready << true
            release.pop
          end
          { count: 42 }
        end
      end
    end
    first = Thread.new { fetch.call(1) }
    Timeout.timeout(5) { ready.pop }
    others = 4.times.map { Thread.new { fetch.call(1) } }
    release << true
    Timeout.timeout(5) do
      ([first] + others).each { |thread| assert_equal({ count: 42 }, thread.value) }
    end
    assert_equal 1, calls
    assert_equal({ count: 42 }, fetch.call(2))
    assert_equal 2, calls
  ensure
    ([first] + Array(others)).compact.each { |thread| thread.kill if thread.alive? }
  end

  test "nested cache fills are reentrant and errors release the lock" do
    assert_equal 7, DashboardCacheFill.synchronize('nested') { DashboardCacheFill.synchronize('nested') { 7 } }
    assert_raises(RuntimeError) { DashboardCacheFill.synchronize('nested') { raise 'failure' } }
    assert_equal 8, DashboardCacheFill.synchronize('nested') { 8 }
  end
end
