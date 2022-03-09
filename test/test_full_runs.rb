require 'minitest/autorun'

require 'log_sense.rb'

class FullRunTest < Minitest::Test
  def test_full_run
    output = { 'apache' => 'sample_logs/short.log', 'rails' => 'sample_logs/emas.log' }
    output.each do |format, file|
      %w[html txt].each do |output_format|
        cli = "--input-format=#{format} --input-files=#{file} --output-format=#{output_format}"
        puts "Running: #{cli}"
        `ruby -Ilib exe/log_sense #{cli}`
      end
    end
  end
end
