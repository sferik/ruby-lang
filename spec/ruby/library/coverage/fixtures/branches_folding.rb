module CoverageSpecs
  def self.folds(a)
    :a if __ENCODING__
    :b if (1; 2)
    :c if (a; [1]; {k: a}; (a..1); 2)
    :d if a || 1
    :e if (nil)
    :f if ("x")
    :g if (true && 1)
    :h if nil && 1
    :i if ([a]; 2)
    if false
      def dead(x) = x ? 1 : 2
      [1].each { |x| x ? 1 : 2 }
    end
    a => Integer
    a in String
  end
end
