module Proxy::TFTP
  class BootFilesInProgress < StandardError
    def status_code
      409
    end
  end

  # Coordinates writes and reads of TFTP paths so conflicting operations can
  # fail fast instead of waiting on work in progress.
  class DirLock
    def initialize
      @mutex = Mutex.new
      @active = {}
    end

    # Call defer_release when handing the reservation to async work. That work
    # must call release on completion. Otherwise, release happens on block exit.
    def with_write(paths)
      registered = false
      deferred = false
      released = false
      release_mutex = Mutex.new
      release = proc do
        should_release = release_mutex.synchronize do
          next false if released
          released = true
        end
        release_write(paths) if should_release
      end
      defer_release = proc { deferred = true }

      paths = reserve_write(paths)
      registered = true
      yield release, defer_release
    ensure
      release.call if registered && !deferred
    end

    def with_read(paths)
      reserved_paths = reserve_read(paths)
      yield
    ensure
      release_read(reserved_paths) if reserved_paths
    end

    def active?(path)
      @mutex.synchronize do
        @active.any? { |active_path, entry| entry[:writer] && paths_conflict?(active_path, path.to_s) }
      end
    end

    private

    def reserve_write(paths)
      paths = normalize_paths(paths)
      @mutex.synchronize do
        busy_path = paths.find do |path|
          @active.keys.find { |active_path| paths_conflict?(active_path, path) }
        end
        raise BootFilesInProgress, "TFTP files are already being updated: #{busy_path}" if busy_path

        paths.each { |path| @active[path] = { writer: true, readers: 0 } }
      end
      paths
    end

    def release_write(paths)
      @mutex.synchronize do
        paths.each do |path|
          entry = @active[path.to_s]
          @active.delete(path.to_s) if entry && entry[:writer]
        end
      end
    end

    def reserve_read(paths)
      paths = normalize_paths(paths)
      @mutex.synchronize do
        busy_path = paths.find do |path|
          @active.any? { |active_path, entry| entry[:writer] && paths_conflict?(active_path, path) }
        end
        raise BootFilesInProgress, "Bootloader universe files are currently being downloaded or extracted: #{busy_path}" if busy_path

        paths.each do |path|
          entry = @active[path] ||= { writer: false, readers: 0 }
          entry[:readers] += 1
        end
      end
      paths
    end

    def release_read(paths)
      @mutex.synchronize do
        paths.each do |path|
          entry = @active[path.to_s]
          next unless entry && entry[:readers].positive?

          entry[:readers] -= 1
          @active.delete(path.to_s) if entry[:readers].zero? && !entry[:writer]
        end
      end
    end

    def normalize_paths(paths)
      paths.map(&:to_s).uniq
    end

    def paths_conflict?(first, second)
      first == second || first.start_with?("#{second}#{File::SEPARATOR}") || second.start_with?("#{first}#{File::SEPARATOR}")
    end
  end
end
