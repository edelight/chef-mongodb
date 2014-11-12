require 'rspec'
require_relative '../../libraries/replicaset_config'
require_relative '../../libraries/replicaset_coordinator'

describe 'ReplicasetConfig' do
  let(:coord) do
    MongoDBCB::ReplicasetCoordinator.new(
      'default',
      { 'hostname' => 'd.e.f',
        'port' => 27017
      },
      [{
        'hostname' => 'a.b.c',
        'ipaddress' => '1.2.3.4',
        'port' => 27_017,
        'arbiter_only' => 'true',
        'slave_delay' => 5,
        'tags' => {},
        'votes' => 1,
        'build_indexes' => true,
        'hidden' => true
      }]
    )
  end
  it '#local_host_record' do
    expected = {
      'hostname' => 'd.e.f',
      'port' => 27017
    }
    expect(coord.local_host_record).to eq(expected)
  end
  it '#service_host_records' do
    expected = [{
      'hostname' => 'a.b.c',
      'ipaddress' => '1.2.3.4',
      'port' => 27_017,
      'arbiter_only' => 'true',
      'slave_delay' => 5,
      'tags' => {},
      'votes' => 1,
      'build_indexes' => true,
      'hidden' => true
    }]
    expect(coord.service_host_records).to eq(expected)
  end
  it '#name' do
    expect(coord.name).to eq('default')
  end
  it '#replicaset_config' do
    expected = MongoDBCB::ReplicasetConfig.new 'default'
    expected_member = MongoDBCB::ReplicasetMember.new(
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
    expected << expected_member
    actual = coord.replicaset_config
    expect(actual).to eq(expected)
  end

  describe '#configure!' do
    describe 'initiate replicaset times out' do
      it 'should rethrow timeout' do
        # initiate_replicaset should respond w/ ok
        conn = double('conn',
          :database_names => :stub
        )
        expect(Mongo::Connection).to receive(:new) { conn }

        expect(conn).to receive(:initiate_replicaset)
          .and_raise(Mongo::OperationTimeout)

        expect { coord.configure! }.to raise_error(Mongo::OperationTimeout)
      end
    end

    describe 'initiate replicaset is ok' do
      it 'should not explode' do
        # arrange
        # initiate_replicaset should respond w/ ok
        conn = double('conn',
          :database_names => :stub,
          :initiate_replicaset => {
            'ok' => true
          }
        )
        expect(Mongo::Connection).to receive(:new) { conn }
        # act, assert
        expect { coord.configure! }.not_to raise_error
      end
      it 'should submit correct replicaset config' do
        # initiate_replicaset should respond w/ ok
        conn = double('conn',
          :database_names => :stub,
          :initiate_replicaset => {
            'ok' => true
          }
        )
        expect(Mongo::Connection).to receive(:new) { conn }

        replicaset_config = {
          '_id' => 'default',
          'version' => 1,
          'members' => [
            { 'host' => 'a.b.c:27017',
              'arbiterOnly' => true,
              'buildIndexes' => true,
              'hidden' => true,
              'slaveDelay' => 5,
              'priority' => 0,
              'tags' => {},
              'votes' => 1
            }
          ]
        }

        # act
        coord.configure!

        # assert
        expect(conn).to have_received(:initiate_replicaset)
          .with(replicaset_config, :check_response => false)
      end
    end

    describe 'already initialized' do
      describe 'from another server'
      describe 'from local server'

      describe 'and current config matches' do
        it 'returns sucessfully'
      end

      describe 'and current config matches by ipaddress'
      describe 'and current config differs'

      describe 'after update' do
        describe 'and current config matches'
        describe 'and current config does not match'
      end
    end
  end
end
