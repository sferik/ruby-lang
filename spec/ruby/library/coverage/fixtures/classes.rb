module CoverageSpecs
  # Writes code to a temporary file, loads it with line coverage enabled and returns the line counts
  def self.line_coverage(code)
    with_file(code) do |path|
      Coverage.start(lines: true)
      load path
      Coverage.result.fetch(path)[:lines]
    end
  end

  def self.with_file(code)
    path = tmp("coverage_spec.rb")
    File.write(path, code)
    yield File.realpath(path)
  ensure
    Coverage.result unless Coverage.state == :idle
    rm_r path
  end
end
