require 'chefspec'
require 'chefspec/berkshelf'

describe 'mongodb::mms-agent' do
  let(:chef_run) {
    stub_command("/usr/bin/python -c 'import setuptools'").and_return(true)
    ChefSpec::Runner.new(platform: 'ubuntu', version: '12.04') do |n|
      n.set.mongodb.mms_agent.install_dir = '/usr/local/share'
    end
  }

  it 'installs munin by default' do
    chef_run.converge(described_recipe)
    expect(chef_run).to install_package(chef_run.node.mongodb.mms_agent.munin_package)
  end

  it 'does not install munin if you say so' do
    chef_run.node.set.mongodb.mms_agent.install_munin = false
    chef_run.converge(described_recipe)
    expect(chef_run).not_to install_package(chef_run.node.mongodb.mms_agent.munin_package)
  end

  describe 'chefspec actually issues real commands on the local client, disabled for now' do
    xit 'does not clobber anything else' do
      # add some files to install_dir
      expected_file = "#{chef_run.node.mongodb.mms_agent.install_dir}/f.txt"
      expected_string = "hello mongodb"
      File.open(expected_file, 'w') { |f| f.write(expected_string) }

      # converge and check the file and string are still there
      chef_run.converge(described_recipe)
      File.open(expected_file, 'r') { |f| expect(f.read).to eq(expected_string) }
    end
  end
end
