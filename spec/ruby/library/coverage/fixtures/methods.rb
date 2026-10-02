module CoverageSpecs
  class Covered
    def plain(a, b = 1, *c, d:, **e, &f); end
    define_method(:block) { |x| x }
    define_method(:lam, &->(x) { x })
    alias aliased plain
    def self.single; end
    class << self
      def single2; end
    end
    def strict(a); end
    def keyword(a:); end
    def default(a = raise("boom")); end
    def multi(a,
              b)
    end
  end

  module Mixin
    def mixed; end
    module_function :mixed
  end

  class Prepended
    prepend Module.new
    def prepended; end
  end

  class Sub < Covered
    private :plain
  end
end
