module CoverageSpecs
  class Covered
    def original; end
  end

  class Sub < Covered
    define_method(:renamed, instance_method(:original))
  end
end
