require 'rspec'
require_relative '../../libraries/replicaset_config'

describe 'ReplicasetConfig' do
  let(:member) do
    MongoDBCB::ReplicasetMember.new(
      { 'hostname' => 'a.b.c',
        'ipaddress' => '1.2.3.4',
        'port' => 27_017,
        'arbiter_only' => 'true',
        'slave_delay' => 5,
        'tags' => {},
        'votes' => 1,
        'build_indexes' => true,
        'hidden' => true
      },
      0
    )
  end

  let(:config) do
    config = MongoDBCB::ReplicasetConfig.new 'rs_test'
    config << member
    config
  end

  it '#id' do
    expect(config.id).to eq('rs_test')
  end

  it '#<<' do
    expect(config.members[member.host]).to eq(member)
  end

  it '#to_doc' do
    expected = {
      '_id' =>      'rs_test',
      'members' =>  [{
        '_id' =>           0,
        'host' =>          'a.b.c:27017',
        'arbiterOnly' =>   true,
        'buildIndexes' =>  true,
        'hidden' =>        true,
        'slaveDelay' =>    5,
        'priority' =>      0,
        'tags' =>          {},
        'votes' =>         1
      }],
      'version' => 1
    }
    expect(config.to_doc).to eq(expected)
  end

  it '#member_list' do
    expected = [{
      '_id' =>           0,
      'host' =>          'a.b.c:27017',
      'arbiterOnly' =>   true,
      'buildIndexes' =>  true,
      'hidden' =>        true,
      'slaveDelay' =>    5,
      'priority' =>      0,
      'tags' =>          {},
      'votes' =>         1
    }]
    expect(config.member_list).to eq(expected)
  end

  it '#matches?' do
    other = {
      '_id' =>      'rs_test',
      'members' =>  [{
        '_id' =>           0,
        'host' =>          'a.b.c:27017',
        'arbiterOnly' =>   true,
        'buildIndexes' =>  true,
        'hidden' =>        true,
        'slaveDelay' =>    5,
        'priority' =>      0,
        'tags' =>          {},
        'votes' =>         1
      }]
    }
    expect(config.matches? other).to eq(true)
  end

  it '#matches_by_ipaddress?' do
    other = {
      '_id' =>      'rs_test',
      'members' =>  [{
        '_id' =>           0,
        'host' =>          '1.2.3.4:27017'
      }]
    }
    expect(config.matches_by_ipaddress? other).to eq(true)
  end

  it '#inspect' do
    expected = '<ReplicasetConfig id="rs_test" members="a.b.c:27017" version=1>'
    expect(config.inspect).to eq(expected)
  end

  it '#==' do
    expected = MongoDBCB::ReplicasetConfig.new 'rs_test'
    expected << MongoDBCB::ReplicasetMember.new(
      { 'hostname' => 'a.b.c',
        'ipaddress' => '1.2.3.4',
        'port' => 27_017,
        'arbiter_only' => 'true',
        'slave_delay' => 5,
        'tags' => {},
        'votes' => 1,
        'build_indexes' => true,
        'hidden' => true
      },
      0
    )
    expect(config).to eq(expected)
  end
end
