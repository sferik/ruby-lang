module CoverageSpecs
  class Covered
    BLK = proc { |a| a }
    define_method(:blk, &BLK)
  end
end
