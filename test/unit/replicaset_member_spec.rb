require 'rspec'
require_relative '../../libraries/replicaset_member'

describe 'ReplicasetMember' do
  let(:raw) do
    {
      'hostname' => 'a.b.c',
      'ipaddress' => '1.2.3.4',
      'port' => 27_017,
      'arbiter_only' => 'true',
      'slave_delay' => 5,
      'tags' => {},
      'votes' => 1,
      'build_indexes' => true,
      'hidden' => true
    }
  end
  let(:minimal) do
    {
      'hostname' => 'a.b.c'
    }
  end
  it 'should convert to hash' do
    member = MongoDBCB::ReplicasetMember.new raw
    expected = {
      'host' => 'a.b.c:27017',
      'arbiterOnly' => true,
      'buildIndexes' => true,
      'hidden' => true,
      'slaveDelay' => 5,
      'priority' => 0,
      'tags' => {},
      'votes' => 1
    }
    expect(member.to_h).to eq(expected)
  end
  it 'should convert to hash with id when given' do
    member = MongoDBCB::ReplicasetMember.new raw, 5
    expected = {
      'host' => 'a.b.c:27017',
      'arbiterOnly' => true,
      'buildIndexes' => true,
      'hidden' => true,
      'slaveDelay' => 5,
      'priority' => 0,
      'tags' => {},
      'votes' => 1,
      '_id' => 5
    }
    expect(member.to_h).to eq(expected)
  end
  it 'should convert to hash with id when given' do
    member = MongoDBCB::ReplicasetMember.new raw, 5
    expected = {
      'host' => '1.2.3.4:27017',
      '_id' => 5
    }
    expect(member.to_h_with_ipaddress).to eq(expected)
  end
  it 'should respond to #==' do
    actual = MongoDBCB::ReplicasetMember.new raw
    expected =  MongoDBCB::ReplicasetMember.new(
      'hostname' => 'a.b.c',
      'ipaddress' => '1.2.3.4',
      'port' => 27_017,
      'arbiter_only' => 'true',
      'slave_delay' => 5,
      'tags' => {},
      'votes' => 1,
      'build_indexes' => true,
      'hidden' => true
    )
    expect(actual).to eq(expected)
  end
end

describe 'ReplicasetMember::ChefNode' do
  let(:chef_node) do
    {
      'fqdn' => 'a.b.c',
      'ipaddress' => '1.2.3.4',
      'mongodb' => {
        'config' => {
          'port' => 27_017
        },
        'replica_arbiter_only' => true,
        'replica_slave_delay' => 5,
        'replica_priority' => 0,
        'replica_tags' => {},
        'replica_votes' => 1,
        'replica_build_indexes' => true,
        'replica_hidden' => true
      }
    }
  end
  describe '::load' do
    it 'should pass through ReplicasetMember correctly' do
      # TODO: OMGTWFBBQ namespace
      node = MongoDBCB::ReplicasetMember::ChefNode.load chef_node
      member = MongoDBCB::ReplicasetMember.new node
      expected = {
        'host' => 'a.b.c:27017',
        'arbiterOnly' => true,
        'buildIndexes' => true,
        'hidden' => true,
        'slaveDelay' => 5,
        'priority' => 0,
        'tags' => {},
        'votes' => 1
      }
      expect(member.to_h).to eq(expected)
    end
  end
  it 'should convert to hash' do
    member = MongoDBCB::ReplicasetMember::ChefNode.new chef_node
    expected = {
      'hostname' => 'a.b.c',
      'port' => 27017,
      'arbiter_only' => true,
      'build_indexes' => true,
      'hidden' => true,
      'slave_delay' => 5,
      'priority' => 0,
      'tags' => {},
      'votes' => 1,
      'ipaddress' => '1.2.3.4'
    }
    expect(member.to_h).to eq(expected)
  end
end
