require "minitest/autorun"
require "ssh_test"

class TestSSH < Minitest::Test
  def setup
    super
    @ssh = SSH.new
    @ssh.commands = []
    @ssh.output   = []
    @ssh.error    = []
    @ssh.action   = nil
  end

  def test_run
    @ssh.output << "file1\nfile2\n"
    @ssh.target_host = "app.example.com"
    result = nil

    out, err = capture_io do
      result = @ssh.run("ls")
    end

    commands = @ssh.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ["ssh", "app.example.com", "ls"],
                 commands.first, 'app'
    assert_equal "file1\nfile2\n", result

    assert_equal "file1\nfile2\n", out
    assert_equal '', err
  end

  def test_run_dir
    @ssh.target_host = "app.example.com"
    @ssh.target_dir  = "/www/dir1"

    @ssh.run("ls")

    commands = @ssh.commands

    assert_equal [["ssh", "app.example.com", "cd /www/dir1 && ls"]], commands
  end

  def test_run_failing_command
    @ssh.input = StringIO.new "file1\nfile2\n"
    @ssh.target_host =  'app.example.com'
    @ssh.action = proc { 1 }

    e = assert_raises(SSH::CommandFailedError) { @ssh.run("ls") }
    assert_equal "Failed with status 1: ssh app.example.com ls", e.message

    assert_equal [["ssh", "app.example.com", "ls"]], @ssh.commands
  end

  def test_run_sudo
    @ssh.output << "file1\nfile2\n"
    @ssh.error << 'Password:'
    @ssh.target_host = "app.example.com"
    @ssh.sudo_password = "my password"
    result = nil

    out, err = capture_io do
      result = @ssh.run("sudo ls")
    end

    commands = @ssh.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ['ssh', 'app.example.com', 'sudo ls'],
                 commands.first

    assert_equal "my password\n", @ssh.input.string

    # WARN: Technically incorrect, the password line should be
    # first... this is an artifact of changes to the IO code in run
    # and the fact that we have a very simplistic (non-blocking)
    # testing model.
    assert_equal "file1\nfile2\nPassword:\n", result

    assert_equal "file1\nfile2\n", out
    assert_equal "Password:\n", err
  end
end
