require "rspec"
require "fake_web"

require "check_graphite"

describe CheckGraphite::Command do
  before do
    FakeWeb.allow_net_connect = false
  end

  describe "it should make http requests and return data" do
    before do
      FakeWeb.register_uri(:get, "http://your.graphite.host/render?target=collectd.somebox.load.load.midterm&from=-30seconds&format=json",
                           :body => '[{"target": "default.test.boottime", "datapoints": [[1.0, 1339512060], [3.0, 1339512120]]}]',
                           :content_type => "application/json")
    end

    it "should just work" do
      ARGV = %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm }
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK|value=2.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should be critical" do
      ARGV = %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -c 0 }
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("CRITICAL|value=2.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end
  end

  describe "it should make http requests with basic auth and return data" do
    before do
      FakeWeb.register_uri(:get, "http://baduser:badpass@your.graphite.host/render?target=collectd.somebox.load.load.midterm&from=-30seconds&format=json",
                           :body => "Unauthorized", :status => ["401", "Unauthorized"])

      FakeWeb.register_uri(:get, "http://testuser:testpass@your.graphite.host/render?target=collectd.somebox.load.load.midterm&from=-30seconds&format=json",
                           :body => '[{"target": "default.test.boottime", "datapoints": [[1.0, 1339512060], [3.0, 1339512120]]}]',
                           :content_type => "application/json")
    end

    it "should work with valid username and password" do
      ARGV = %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -U testuser -P testpass}
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK|value=2.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should fail with bad username and password" do
      ARGV = %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -U baduser -P badpass }
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(/UNKNOWN: INTERNAL ERROR: HTTP error code 401/)
      lambda { c.run }.should raise_error SystemExit
    end
  end
end