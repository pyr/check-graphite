require 'attime'

describe 'CheckGraphite.attime' do
  subject do |example|
    delta = example.metadata[:description_args][0]
    CheckGraphite.attime(delta, now)
  end

  let(:now) { Time.now }

  def timedelta(n)
    now + n
  end

  it("10days") { should be_within(0.9).of(timedelta(10 * 86400)) }
  it("0days") { should be_within(0.9).of(timedelta(0)) }
  it("1.5days") { should be_within(0.9).of(timedelta(1.5 * 86400)) }
  it("-10days") { should be_within(0.9).of(timedelta(-10 * 86400)) }
  it("5seconds") { should be_within(0.9).of(timedelta(5)) }
  it("5minutes") { should be_within(0.9).of(timedelta(5 * 60)) }
  it("5hours") { should be_within(0.9).of(timedelta(5 * 3600)) }
  it("5weeks") { should be_within(0.9).of(timedelta(86400 * 7 * 5)) }
  it("1month") { should be_within(0.9).of(timedelta(30 * 86400)) }
  it("2months") { should be_within(0.9).of(timedelta(60 * 86400)) }
  it("12months") { should be_within(0.9).of(timedelta(360 * 86400)) }
  it("1year") { should be_within(0.9).of(timedelta(365 * 86400)) }
  it("2years") { should be_within(0.9).of(timedelta(730 * 86400)) }

  it(1) { expect { subject }.to raise_error(/string/i) }
  it("Something") { expect { subject }.to raise_error(RuntimeError) }
  it("1m") { expect { subject }.to raise_error(/bad unit/i) }
  it("1day 1day") { expect { subject }.to raise_error(/bad unit/i) }
  it("10") { expect { subject }.to raise_error(/unit/) }
  it("month") { expect { subject }.to raise_error(/scalar/) }
end
