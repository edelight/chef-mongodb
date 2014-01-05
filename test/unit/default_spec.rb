require 'chefspec'
require 'chefspec/berkshelf'
require 'fauxhai'

describe 'mongodb::default' do
  before do
    runner = ChefSpec::Runner.new(platform: 'ubuntu', version: '12.04')
    @chef_run = runner.converge 'mongodb::default'
  end
  subject { @chef_run }
  it { should enable_service 'mongodb' }
end
