#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/lockfile'

describe Puppet::Util::Lockfile do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::Lockfile.new(@lockfile)
  end

  describe "#lock" do
    it "should return false if already locked" do
      @lock.stubs(:locked?).returns(true)
      @lock.lock.should be_false
    end

    it "should return true if it successfully locked" do
      @lock.lock.should be_true
    end

    it "should create a lock file" do
      @lock.lock

      Puppet::FileSystem.exist?(@lockfile).should be_true
    end

    # We test simultaneous locks using fork which isn't supported on Windows.
    it "should not be acquired by another process", :unless => Puppet.features.microsoft_windows? do
      5.times do |i|
        first_read, first_write = IO.pipe
        first_pid = fork do
          first_read.close
          success = @lock.lock(Process.pid)
          Marshal.dump(success, first_write)
        end
        second_read, second_write = IO.pipe
        second_pid = fork do
          second_read.close
          success = @lock.lock(Process.pid)
          Marshal.dump(success, second_write)
        end

        Process.wait(first_pid)
        Process.wait(second_pid)
        first_write.close
        second_write.close
        first_result = Marshal.load(first_read.read)
        second_result = Marshal.load(second_read.read)

        @lock.unlock

        first_result.should_not eq(second_result)
      end
    end

    it "should create a lock file containing a string" do
      data = "foofoo barbar"
      @lock.lock(data)

      File.read(@lockfile).should == data
    end
  end

  describe "#unlock" do
    it "should return true when unlocking" do
      @lock.lock
      @lock.unlock.should be_true
    end

    it "should return false when not locked" do
      @lock.unlock.should be_false
    end

    it "should clear the lock file" do
      File.open(@lockfile, 'w') { |fd| fd.print("locked") }
      @lock.unlock
      Puppet::FileSystem.exist?(@lockfile).should be_false
    end
  end

  it "should be locked when locked" do
    @lock.lock
    @lock.should be_locked
  end

  it "should not be locked when not locked" do
    @lock.should_not be_locked
  end

  it "should not be locked when unlocked" do
    @lock.lock
    @lock.unlock
    @lock.should_not be_locked
  end

  it "should return the lock data" do
    data = "foofoo barbar"
    @lock.lock(data)
    @lock.lock_data.should == data
  end
end
