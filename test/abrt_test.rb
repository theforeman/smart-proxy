require 'test_helper'
require 'proxy/abrtproxy'
require 'tmpdir'
require 'fileutils'

class AbrtTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir "foreman-proxy-test"
    FileUtils.cp Dir["test/fixtures/abrt/ureport-ondisk-*"], @tmpdir

    SETTINGS.stubs(:abrt_aggregate_reports).returns(false)
    SETTINGS.stubs(:abrt_spooldir).returns(@tmpdir)
  end

  def teardown
    FileUtils.rm_rf @tmpdir
  end

  def test_multipart_form_data_file
    file_contents = '{"foo":"bar"}'
    headers, body = Proxy::AbrtProxy.form_data_file(file_contents, 'application/json')
    request_text = "POST /abrt/whatever/ HTTP/1.1\r\n"
    headers.each do |key,value|
      request_text << key + ": " + value + "\r\n"
    end
    request_text << "\r\n"
    request_text << body

    req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
    req.parse(StringIO.new(request_text))

    assert_equal req.request_method, "POST"
    assert_equal req.query["file"], file_contents
  end

  def test_hostreport_open
    file = File.join @tmpdir, "ureport-ondisk-host1-01"
    hr = Proxy::AbrtProxy::HostReport.new file
    assert_equal "f19-managed.virtnet", hr.host
    assert_equal [file], hr.files
    assert_equal 1, hr.reports.size
  end

  def test_hostreport_load_directory
    reports = Proxy::AbrtProxy::HostReport.load_from_spool
    assert_equal 4, reports.size
    reports.each { |r| assert r.is_a?(Proxy::AbrtProxy::HostReport) }
  end

  def test_hostreport_merge_without_duphash
    reports = []
    Dir[File.join(@tmpdir, "ureport-ondisk-host1-*")].each do |file|
      reports << Proxy::AbrtProxy::HostReport.new(file)
    end

    assert_equal 3, reports.size
    r = reports[0]
    r.merge(reports[1])
    r.merge(reports[2])

    # no merging by duphash
    assert_equal 3, r.reports.size
  end

  def test_hostreport_merge_with_duphash
    base = File.join(@tmpdir, "ureport-ondisk-host1-")
    reports = []
    Proxy::AbrtProxy::HostReport.stubs(:duphash).returns("aaa")
    reports << Proxy::AbrtProxy::HostReport.new(base + "01")
    reports << Proxy::AbrtProxy::HostReport.new(base + "02")
    Proxy::AbrtProxy::HostReport.stubs(:duphash).returns("bbb")
    reports << Proxy::AbrtProxy::HostReport.new(base + "03")
    Proxy::AbrtProxy::HostReport.unstub(:duphash)

    r = reports[0]
    r.merge(reports[1])
    r.merge(reports[2])

    # first two reports should be merged
    assert_equal 2, r.reports.size
  end

  def test_hostreport_send_to_foreman
    Proxy::Request::Reports.any_instance.expects(:post_report).once

    reports = []
    Dir[File.join(@tmpdir, "ureport-ondisk-host1-*")].each do |file|
      reports << Proxy::AbrtProxy::HostReport.new(file)
    end

    r = reports[0]
    r.merge(reports[1])
    r.merge(reports[2])

    r.send_to_foreman
  end

  def test_hostreport_unlink
    # single report
    r1 = Proxy::AbrtProxy::HostReport.new File.join(@tmpdir, "ureport-ondisk-host2-01")
    r1.unlink

    # merged reports
    r2 = Proxy::AbrtProxy::HostReport.new File.join(@tmpdir, "ureport-ondisk-host1-01")
    r2.merge Proxy::AbrtProxy::HostReport.new(File.join(@tmpdir, "ureport-ondisk-host1-02"))
    r2.merge Proxy::AbrtProxy::HostReport.new(File.join(@tmpdir, "ureport-ondisk-host1-03"))
    r2.unlink

    dir_contents = Dir[File.join(@tmpdir, "*")]
    assert dir_contents.empty?, "Not all files were deleted"
  end

  def test_hostreport_save
    Dir[File.join(@tmpdir, "*")].each { |file| File.unlink file }
    ureport = IO.read "test/fixtures/abrt/ureport1.json"
    ureport = JSON.parse ureport
    Proxy::AbrtProxy::HostReport.save "localhost", ureport

    hr = Proxy::AbrtProxy::HostReport.new Dir[File.join(@tmpdir, "*")][0]
    assert_equal "localhost", hr.host
    assert_equal 1, hr.reports.size
  end
end
