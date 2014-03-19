require 'chefspec'
require 'chefspec/berkshelf'
require 'fauxhai'

describe 'mongodb::default' do
  let(:chef_run) { ChefSpec::Runner.new(:platform => 'ubuntu', :version => '12.04') }
  it 'propagates backport attributes' do
    chef_run.node.set['mongodb']['dbpath'] = '/disk/mongodb/data'
    chef_run.node.set['mongodb']['logpath'] = '/logs/mongodb'
    chef_run.converge(described_recipe)

    expect(chef_run).to enable_service 'mongodb'

    expect(chef_run.node['mongodb']['config']['dbpath']).to eq('/disk/mongodb/data')
    expect(chef_run.node['mongodb']['config']['dbpath']).to_not eq('/var/lib/mongo')

    expect(chef_run.node['mongodb']['config']['logpath']).to eq('/logs/mongo/mongod.log')
    expect(chef_run.node['mongodb']['config']['logpath']).to_not eq('/var/log/mongo/mongod.log')
  end
end
