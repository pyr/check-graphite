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

  describe 'when parsing a pearson threshold option' do
    subject do |example|
      check.prepare
      check.send(:parse_options, example.metadata[:description_args][0])
      check.options.p_threshold
    end

    it ['--p-threshold', '0.75'] { should eq(0.75) }
    it ['--p-threshold', '2'] { expect { subject }.to raise_error(/0 <=.*2.*<= 1/) }
    it ['--p-threshold', 'foo'] { expect { subject }.to raise_error(/float/) }
  end

  describe 'when looking at the primary value' do
    let(:projection) { '2sec' }
    let(:options) { ['--projection', projection] }

    subject do
      check.prepare
      check.send(:parse_options, options)
      check.options.processor.call(datapoints)
      check.values.first[1]
    end

    context 'given a linearly decreasing series and a projection of 2 sec' do
      let(:datapoints) { [[10,0], [9,1], [8,2]] }

      it { should be_within(0.01).of(6) }
    end

    context 'given a constant series and a projection of 2 sec' do
      let(:datapoints) { [[10,0], [10,1], [10,2]] }

      it { should be_within(0.01).of(10) }
    end

    context 'given a constant series with a p-value below threshold' do
      let(:datapoints) { [[10,0], [10,1], [10,2]] }
      let(:options) { ['--projection', projection, '--p-threshold', '0.3'] }

      it 'returns a projection even tho p-value is NaN' do
        should be_within(0.01).of(10)
      end
    end

    context 'given a series with a p-value below threshold' do
      let(:datapoints) { [[5,0], [1,1], [10,2]] }
      let(:options) { ['--projection', projection, '--p-threshold', '0.9'] }

      it 'returns nil because nagios_check will turn it into UNKNOWN' do
        should be(nil)
      end
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
    stub_const("ARGV", %w{
      -H http://your.graphite.host/render
      -M collectd.somebox.load.load.midterm
      -c 0:10
      --name ze-name
    } + options)
  end

  context 'given no --p-threshold' do
    let(:options) { ['--projection', '5min'] }

    it 'outputs value, projection interval and p-value' do
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(match(/ze-name.*in 5min.*p-value=0.9/))
      lambda { c.run }.should raise_error SystemExit
    end
  end

  context 'given a low p-threshold' do
    let(:options) { ['--projection', '5min', '--p-threshold', '0.3'] }

    it 'outputs value, projection interval and p-value' do
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(match(/ze-name.*in 5min.*p-value=0.9/))
      lambda { c.run }.should raise_error SystemExit
    end
  end

  context 'given a high p-threshold' do
    let(:options) { ['--projection', '5min', '--p-threshold', '0.99'] }

    it 'gives unknown status and says p-value is too low' do
      c = CheckGraphite::Command.new
      STDOUT.should_receive(:puts).with(match(/UNKNOWN.*ze-name.*.*0.981 < 0.99/))
      lambda { c.run }.should raise_error SystemExit
    end
  end
end
