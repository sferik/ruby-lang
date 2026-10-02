module CoverageSpecs
  class Branchy
    def classify(x)
      if x > 0
        :positive
      elsif x < 0
        :negative
      else
        :zero
      end
    end

    def describe(x)
      kind = x.zero? ? :zero : :nonzero
      kind = :big unless x < 100
      case x
      when 0 then :none
      when 1, 2
        :few
      else
        :many
      end
    end

    def count_down(x)
      while x > 0
        x -= 1
      end
      x += 1 until x > 2
      x
    end

    def safe(x)
      x&.abs
    end

    def match(x)
      case x
      in Integer => n if n > 10 then :large
      in Integer
        :small
      end
    end
  end
end
