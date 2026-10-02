module CoverageSpecs
  class Covered
    def self.Make(&b) = b
    define_method (:brace) { |x| x }
    define_method (
      :do_block
    ) do |x|
      x
    end
  end
  made = Covered::Make { |x| x }
  Covered.define_method(:constant_call, &made)
end
