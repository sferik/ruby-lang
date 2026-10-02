module CoverageSpecs
  class Covered
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def from_eval(x); x; end
    RUBY
  end
end
