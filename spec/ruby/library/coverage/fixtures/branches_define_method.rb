module CoverageSpecs
  class Reloaded
    define_method(:sign) { |x| x < 0 ? :neg : :pos }
  end
end
