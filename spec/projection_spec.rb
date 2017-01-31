require 'check_graphite/projection'
require 'nagios_check'

describe CheckGraphite::Projection do
  let :check do
    Class.new do
      attr_reader :values
      include NagiosCheck
      include CheckGraphite::Projection
    end.new
  end

  describe 'when looking at the primary value' do
    subject do
      check.prepare
      check.send(:parse_options, ['--projection', projection])
      check.options.processor.call(datapoints)
      check.values.first[1]
    end

    context 'given a linearly decreasing series and a projection of 2 sec' do
      let(:projection) { '2sec' }
      let(:datapoints) { [[10,0], [9,1], [8,2]] }

      it { should be_within(0.01).of(6) }
    end

    context 'given a constant series and a projection of 2 sec' do
      let(:projection) { '2sec' }
      let(:datapoints) { [[10,0], [10,1], [10,2]] }

      it { should be_within(0.01).of(10) }
    end
  end

  describe 'when looking at the p-value' do
    subject do
      check.prepare
      check.send(:parse_options, ['--projection', projection])
      check.options.processor.call(datapoints)
      check.values['p-value']
    end

    context 'given a constant series (where Pearson is undefined)' do
      let(:projection) { '2sec' }
      let(:datapoints) { [[10,0], [10,1], [10,2]] }
      it { should eq('undefined') }
    end

    context 'given a linearly decreasing series' do
      let(:projection) { '2sec' }
      let(:datapoints) { [[10,0], [9,1], [8,2]] }

      it { should eq("1.0") }
    end
  end
end

describe 'when invoking graphite with --projection' do
  before do
    FakeWeb.register_uri(
      :get, "http://your.graphite.host/render?target=collectd.somebox.load.load.midterm&from=-30seconds&format=json",
      :body => '[{"target": "collectd.somebox.load.load.midterm", "datapoints": [[1.0, 1339512060], [2.0, 1339512120], [6.0, 1339512180], [7.0, 1339512240]]}]',
      :content_type => "application/json"
    )
  end

  it 'outputs value, projection interval and p-value' do
    stub_const("ARGV", %w{
      -H http://your.graphite.host/render
      -M collectd.somebox.load.load.midterm
      -c 0:10
      --projection 5min
      --name ze-name
    })
    c = CheckGraphite::Command.new
    STDOUT.should_receive(:puts).with(match(/ze-name.*in 5min.*p-value=0.9/))
    lambda { c.run }.should raise_error SystemExit
  end
end
