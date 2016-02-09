require 'rubygems'
require 'open4'

##
# SSH provides a simple streaming ssh command runner. That's it.
# This is a one trick pony.
#
#   ssh = SSH.new "example.com", "/var/log"
#   puts ssh.run "ls"
#
# SSH was extracted from rake-remote_task which was extracted from vlad.
#
# SSH's idea contributed by Joel Parker Henderson.

class SSH
  VERSION = "1.1.1"

  class Error < RuntimeError; end

  class CommandFailedError < Error
    attr_reader :status
    def initialize status
      @status = status
    end
  end

  include Open4

  attr_accessor :ssh_cmd, :ssh_flags, :target_host, :target_dir

  def initialize target_host = nil, target_dir = nil
    self.ssh_cmd       = "ssh"
    self.ssh_flags     = []
    self.target_host   = target_host
    self.target_dir    = target_dir
  end

  def run command, stdin: nil
    command = "cd #{target_dir} && #{command}" if target_dir
    cmd     = [ssh_cmd, ssh_flags, target_host, command].flatten

    if $DEBUG then
      trace = [ssh_cmd, ssh_flags, target_host, "'#{command}'"]
      warn trace.flatten.join ' '
    end

    pid, inn, out, err = popen4(*cmd)

    inn.puts stdin if stdin
    inn.close if stdin

    status, stdout, stderr = empty_streams pid, inn, out, err, stdin.nil?

    stdout = stdout.join.gsub(/\n\n$/, "\n")
    stderr = stderr
             .join
             .gsub(/\n\n$/, "\n")
             .gsub(/Warning: Permanently added.+to the list of known hosts\.\s+/, '')

    { stdout: stdout, stderr: stderr, status: status.exitstatus }
  ensure
    inn.close rescue nil
    out.close rescue nil
    err.close rescue nil
  end

  def empty_streams(pid, inn, out, err, sync)
    stdout  = []
    stderr  = []
    inn.sync   = true if sync
    streams    = [out, err]

    # Handle process termination ourselves
    status = nil
    Thread.start do
      status = Process.waitpid2(pid).last
    end

    until streams.empty?
      # don't busy loop
      selected, = select streams, nil, nil, 0.1

      next if selected.nil? || selected.empty?

      selected.each do |stream|
        if stream.eof?
          streams.delete stream if status # we've quit, so no more writing
          next
        end

        data = stream.readpartial(1024)

        stdout << data unless stream == err
        stderr << data if stream == err
      end
    end

    return status, stdout, stderr
  end
end
