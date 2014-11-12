require 'chefspec'
require 'chefspec/berkshelf'
require 'fauxhai'

describe 'mongodb::default' do
  let(:chef_run) do
    ChefSpec::Runner.new(
      :platform => 'ubuntu',
      :version => '12.04'
      )
  end

  it 'should include install recipe, and enable mongodb service' do
    chef_run.converge(described_recipe)
    chef_run.should include_recipe('mongodb::install')
    chef_run.should enable_service 'mongodb'
  end

  it 'package install mongodb-org via 10gen' do
    chef_run.node.set.mongodb.install_method = '10gen'
    chef_run.converge(described_recipe)
    chef_run.should include_recipe('mongodb::10gen_repo')
    chef_run.should include_recipe('mongodb::install')
    chef_run.should install_package 'mongodb-org'
    chef_run.should enable_service 'mongodb'
  end

  it 'package install mongodb-org via mongodb-org' do
    chef_run.node.set.mongodb.install_method = 'mongodb-org'
    chef_run.converge(described_recipe)
    chef_run.should include_recipe('mongodb::10gen_repo')
    chef_run.should include_recipe('mongodb::install')
    chef_run.should install_package 'mongodb-org'
    chef_run.should enable_service 'mongodb'
  end

end
