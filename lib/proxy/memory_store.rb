module Proxy
  class MemoryStore
    def initialize
      @root = {}
    end

    def [](*path)
      get(@root, path)
    end

    def []=(*args)
      value = args.pop
      put(@root, args, value)
    end

    def delete(*path)
      do_delete(@root, path)
    end

    def values(*path)
      path.empty? ? get_all_values(@root) : get_all_values(get(@root, path))
    end

    private

    def get(store, path)
      ret_val = store[path.first]
      return ret_val if path.size == 1
      ret_val ? get(ret_val, path.slice(1, path.size - 1)) : nil
    end

    def put(store, path, value)
      return store[path.first] = value if path.size == 1

      store[path.first] = {} unless store.key?(path.first)
      put(store[path.first], path.slice(1, path.size - 1), value)
    end

    def do_delete(store, path)
      return store.delete(path.first) if path.size == 1
      do_delete(store[path.first], path.slice(1, path.size - 1))
    end

    def get_all_values(store)
      store.inject([]) do |acc, current|
        acc + (current.last.is_a?(Hash) ? get_all_values(current.last) : [current.last])
      end.flatten
    end
  end
end
