require 'test_helper'
require 'tftp/server'

class TftpDirLockTest < Test::Unit::TestCase
  def setup
    @dir_lock = Proxy::TFTP::DirLock.new
  end

  def test_rejects_a_second_extraction_for_the_same_directory
    directory = '/tftp/bootloader-universe/pxegrub2/test/1/x86_64'

    @dir_lock.with_write([directory]) do
      assert @dir_lock.active?(directory)
      assert_raises(Proxy::TFTP::BootFilesInProgress) do
        @dir_lock.with_write([directory]) {}
      end
    end

    assert !@dir_lock.active?(directory)
  end

  def test_reports_a_different_directory_as_inactive
    @dir_lock.with_write(['/tftp/bootloader-universe/pxegrub2/test/1/x86_64']) do
      assert !@dir_lock.active?('/tftp/bootloader-universe/pxegrub2/test/2/x86_64')
    end
  end

  def test_reader_reservation_prevents_a_writer_from_starting
    directory = '/tftp/bootloader-universe/pxegrub2/test/1/x86_64'

    @dir_lock.with_read([directory]) do
      assert_raises(Proxy::TFTP::BootFilesInProgress) do
        @dir_lock.with_write(["#{directory}/linux"]) {}
      end
    end

    assert_nothing_raised { @dir_lock.with_write(["#{directory}/linux"]) {} }
  end

  def test_allows_different_legacy_files_in_the_same_directory
    first = '/tftp/boot/kernel'
    second = '/tftp/boot/initrd'

    @dir_lock.with_write([first]) do
      assert_nothing_raised { @dir_lock.with_write([second]) {} }
    end
  end

  def test_rejects_a_legacy_file_inside_an_active_extraction
    directory = '/tftp/bootloader-universe/pxegrub2/test/1/x86_64'
    file = "#{directory}/linux"
    archive = "#{directory}/netboot.tar.gz"

    @dir_lock.with_write([archive, file]) do
      assert_raises(Proxy::TFTP::BootFilesInProgress) do
        @dir_lock.with_write([file]) {}
      end
    end
  end
end
