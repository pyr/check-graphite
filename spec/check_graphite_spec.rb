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
                           :body => '[{"target": "default.test.boottime", "datapoints": [[1.0, 1339512060], [2.0, 1339512120], [6.0, 1339512180], [7.0, 1339512240]]}]',
                           :content_type => "application/json")
    end

    it "should return OK" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=4.0|value=4.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should return WARNING" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -w 0 })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("WARNING: value=4.0|value=4.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should return CRITICAL" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -c 0 })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("CRITICAL: value=4.0|value=4.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should honour dropfirst" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm --dropfirst 1 })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=5.0|value=5.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should honour droplast" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm --droplast 1 })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=3.0|value=3.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should honour dropfirst and droplast together" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm --dropfirst 1 --droplast 1 })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=4.0|value=4.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end
  end

  describe "when data contains null values" do
    before do
      FakeWeb.register_uri(:get, "http://your.graphite.host/render?target=collectd.somebox.load.load.midterm&from=-30seconds&format=json",
                           :body => '[{"target": "default.test.boottime", "datapoints": [[1.0, 1339512060], [null, 1339512120], [null, 1339512180], [3.0, 1339512240]]}]',
                           :content_type => "application/json")
    end

    it "should discard them" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=2.0|value=2.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end
  end

  describe "when Graphite returns no data at all" do
    before do
      FakeWeb.register_uri(:get, "http://your.graphite.host/render?target=value.does.not.exist&from=-30seconds&format=json",
                           :body => '[]',
                           :content_type => "application/json")
    end

    it "should be unknown" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M value.does.not.exist })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(/UNKNOWN: INTERNAL ERROR: (RuntimeError: )?no data returned for target/)
      lambda { c.run }.should raise_error SystemExit
    end

    it "should be ok when ignoring missing data" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M value.does.not.exist --ignore-missing -w 1 -c 3 })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(/OK: value missing - ignoring/)
      lambda { c.run }.should raise_error SystemExit
    end
  end

  describe "when Graphite returns only NULL values" do
    before do
      FakeWeb.register_uri(:get, "http://your.graphite.host/render?target=all.values.null&from=-30seconds&format=json",
                           :body => '[{"target": "all.values.null", "datapoints": [[null, 1339512060], [null, 1339512120], [null, 1339512180], [null, 1339512240]]}]',
                           :content_type => "application/json")
    end

    it "should be unknown" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M all.values.null })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(/UNKNOWN: INTERNAL ERROR: (RuntimeError: )?no valid datapoints/)
      lambda { c.run }.should raise_error SystemExit
    end
  end

  describe "when Graphite returns multiple targets" do
    before do
      FakeWeb.register_uri(:get, "http://your.graphite.host/render?target=collectd.somebox*.load.load.midterm&from=-30seconds&format=json",
                           :body => '[{"target": "collectd.somebox2.load.load.midterm", "datapoints": [[null, 1339512060], [null, 1339512120], [null, 1339512180], [null, 1339512240]]},{"target": "collectd.somebox1.load.load.midterm", "datapoints": [[1.0, 1339512060], [2.0, 1339512120], [6.0, 1339512180], [7.0, 1339512240]]}]',
                           :content_type => "application/json")
    end

    it "should return OK" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox*.load.load.midterm })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=4.0|value=4.0;;;;")
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
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -U testuser -P testpass})
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with("OK: value=2.0|value=2.0;;;;")
      lambda { c.run }.should raise_error SystemExit
    end

    it "should fail with bad username and password" do
      stub_const("ARGV", %w{ -H http://your.graphite.host/render -M collectd.somebox.load.load.midterm -U baduser -P badpass })
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(/UNKNOWN: INTERNAL ERROR: (RuntimeError: )?HTTP error code 401/)
      lambda { c.run }.should raise_error SystemExit
    end
  end
end
