require 'minitest/autorun'

require 'log_sense/options_parser'

class OptionsParserTest < Minitest::Test
  def test_input_file_as_option
    argv = "--input-file a.log".split " "

    options = LogSense::OptionsParser.parse argv
    assert_equal "a.log", options[:input_file], "Passing input files from options fails"
  end

  def test_input_file_as_arg
    argv = "a.log".split " "

    options = LogSense::OptionsParser.parse argv
    assert_equal "a.log", options[:input_file] || argv[0], "Passing input files as argument fails"
  end
end
