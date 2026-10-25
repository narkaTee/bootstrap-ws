# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

class OpWrapperTest < Minitest::Test
  WRAPPER = File.expand_path('op', __dir__)

  def setup
    @dir = Dir.mktmpdir('op-wrapper-test-')
    @file = File.join(@dir, 'dummy.env')
    @env = { 'PATH' => "#{@dir}:#{ENV.fetch('PATH')}" }
    File.write(File.join(@dir, 'op.exe'), <<~'RUBY')
      #!/usr/bin/env ruby
      if ARGV.first == 'read'
        expected = ['read', '--no-newline', ARGV[2]]
        expected += ['--account', 'test-account'] if ARGV.include?('--account')
        abort 'unexpected read arguments' unless ARGV == expected
        case ARGV[2]
        when 'op://test/item/token'
          STDOUT.write("dummy token with \"quotes\", $dollars, = and spaces")
        when 'op://test/item/multiline'
          STDOUT.write("first line\r\nsecond line\n")
        when 'op://test/item/nul'
          STDOUT.write("dummy\0value")
        else
          warn 'SENSITIVE-ERROR-MUST-NOT-APPEAR'
          STDOUT.write('SENSITIVE-PARTIAL-OUTPUT')
          exit 1
        end
      else
        require 'json'
        puts JSON.generate(ARGV)
        exit 7
      end
    RUBY
    File.chmod(0o755, File.join(@dir, 'op.exe'))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def invoke(*args)
    Open3.capture3(@env, RbConfig.ruby, WRAPPER, *args)
  end

  def run_template(content, code, *command_args, options: [])
    File.write(@file, content)
    invoke('run', '--no-masking', '--env-file', @file, *options,
           '--', RbConfig.ruby, '-e', code, '--', *command_args)
  end

  def assert_success(result)
    stdout, stderr, status = result
    assert status.success?, "exit #{status.exitstatus}: #{stderr}"
    assert_empty stderr
    stdout
  end

  def test_literals_quotes_comments_crlf_and_inherited_environment
    result = run_template("# comment\r\n\r\nA=\"dummy one\"\r\nB='two=three'\r\nEMPTY=\r\n",
                          'abort unless ENV.fetch("A") == "dummy one" && ENV.fetch("B") == "two=three" && ENV.fetch("EMPTY") == "" && ENV.key?("PATH")')
    assert_success(result)
  end

  def test_secrets_are_resolved_after_parsing_and_account_is_forwarded
    result = run_template("TOKEN=\"op://test/item/token\"\nMULTI=op://test/item/multiline\n", <<~'RUBY', options: ['--account', 'test-account'])
      abort unless ENV.fetch('TOKEN') == 'dummy token with "quotes", $dollars, = and spaces'
      abort unless ENV.fetch('MULTI') == "first line\r\nsecond line\n"
    RUBY
    assert_success(result)
  end

  def test_command_arguments_are_not_parsed_as_wrapper_options
    result = run_template('A=dummy', 'abort unless ARGV == ["--env-file", "a b", "$literal", "--account"]',
                          '--env-file', 'a b', '$literal', '--account')
    assert_success(result)
  end

  def test_lookup_failure_does_not_run_command_or_leak_output
    stdout, stderr, status = run_template('TOKEN=op://test/item/missing', 'puts "COMMAND-RAN"')
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'Secret lookup failed for TOKEN'
    refute_includes stderr, 'SENSITIVE'
  end

  def test_nul_secret_is_rejected_without_leaking
    stdout, stderr, status = run_template('TOKEN=op://test/item/nul', 'puts "COMMAND-RAN"')
    refute status.success?
    assert_empty stdout
    assert_includes stderr, 'NUL byte for TOKEN'
    refute_includes stderr, 'dummy'
  end

  def test_invalid_assignments_fail_without_echoing_contents
    ['INVALID-NAME=private-content', 'export A=private-content', 'A="private-content'].each do |template|
      stdout, stderr, status = run_template(template, 'puts "COMMAND-RAN"')
      refute status.success?
      assert_empty stdout
      assert_includes stderr, 'line 1'
      refute_includes stderr, 'private-content'
    end
  end

  def test_unsupported_or_incomplete_invocations
    [
      ['run', '--env-file', @file, '--', 'true'],
      ['run', '--no-masking', '--unknown', '--', 'true'],
      ['run', '--no-masking', '--env-file'],
      ['run', '--no-masking', '--env-file', @file, '--'],
      ['run', '--no-masking', '--', 'true'],
      ['run', '--no-masking', '--env-file', @file, '--env-file', @file, '--', 'true']
    ].each do |args|
      stdout, stderr, status = invoke(*args)
      refute status.success?
      assert_empty stdout
      assert_includes stderr, 'op wrapper:'
    end
  end

  def test_non_run_commands_are_forwarded_with_exit_status
    stdout, stderr, status = invoke('item', 'get', 'dummy name', '--account', 'test-account')
    assert_equal 7, status.exitstatus
    assert_equal "[\"item\",\"get\",\"dummy name\",\"--account\",\"test-account\"]\n", stdout
    assert_empty stderr
  end

  def test_command_exit_status_is_preserved
    _stdout, stderr, status = run_template('A=dummy', 'exit 23')
    assert_equal 23, status.exitstatus
    assert_empty stderr
  end

  def test_single_command_string_is_not_evaluated_by_a_shell
    File.write(@file, 'A=dummy')
    stdout, _stderr, status = invoke('run', '--no-masking', '--env-file', @file, '--', 'echo SHELL-RAN; true')
    refute status.success?
    assert_empty stdout
  end
end
