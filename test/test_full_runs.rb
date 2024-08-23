require 'minitest/autorun'

require 'log_sense.rb'

class FullRunTest < Minitest::Test
  def test_full_run
    output = { 'apache' => 'sample_logs/short.log', 'rails' => 'sample_logs/emas.log' }
    output.each do |input_format, input_file|
      %w[html txt].each do |output_format|
        cli = "--input-format=#{input_format} --input-files=#{input_file} --output-format=#{output_format}"
        puts "Running: #{cli}"
        exit_status = system("ruby -Ilib exe/log_sense #{cli} > test-#{input_format}.#{output_format}")
        assert exit_status == true
      end
    end
  end
end
