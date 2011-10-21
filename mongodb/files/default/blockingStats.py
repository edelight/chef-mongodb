"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

import threading, time, pymongo, traceback, socket

blockingStatsAgentVersion = "1.3.7"

class BlockingMongoStatsThread( threading.Thread ):
    """ Pull the blocking data from the various hosts. """

    def __init__( self, hostDef, mmsAgent):
        """ Initialize the object """
        threading.Thread.__init__( self )
        self.hostDef = hostDef
        self.mmsAgent = mmsAgent
        self.logger = mmsAgent.logger
        self.monitorConn = None
        self.slowDbStats = False
        self.lastDbStatsCheck = time.time()

    def run( self ):
        """ Pull the data from the various hosts. """

        hostKey = self.hostDef['hostKey']

        self.logger.info( 'starting blocking stats monitoring: ' + hostKey )

        passes = 0

        sleepTime = ( self.mmsAgent.collectionInterval / 2 ) - 1

        if ( sleepTime < 1 ):
            sleepTime = 1

        while not self.mmsAgent.done and self.hostDef['threadRunning']:
            try:
                if passes > 0:
                    time.sleep( sleepTime )

                passes = passes + 1

                if not self.mmsAgent.haveHostDef( hostKey ):
                    continue

                # Close the connection once per hour
                if passes % 60 == 0:
                    if self.monitorConn is not None:
                        self.monitorConn = None

                if not self.monitorConn:
                    self.monitorConn = pymongo.Connection( self.hostDef['mongoUri'] , slave_okay=True )

                # Verify the connection.
                if not self.mmsAgent.isValidMonitorConn( self.hostDef, self.monitorConn ):
                    self.monitorConn = None
                    continue

                stats = self._collectStats( passes )

                try:
                    stats['hostIpAddr'] = socket.gethostbyname(hostKey[0 : hostKey.find( ':' )])
                except:
                    pass

                stats['host'] = self.hostDef['hostname']
                stats['port'] = self.hostDef['port']

                # Make sure we ended up with the same connection.
                if not self.mmsAgent.isValidMonitorConn( self.hostDef, self.monitorConn ):
                    self.monitorConn = None
                    continue

                self.mmsAgent.setHostState( hostKey, 'mongoBlocking', stats )
            except Exception, e:
                if self.monitorConn is not None:
                    try:
                        self.monitorConn.disconnect()
                        self.monitorConn = None
                    except:
                        pass

                self.logger.error( 'Problem collecting blocking data from (check if it is up and DNS): ' + hostKey + " - exception: " + traceback.format_exc( e ) )

        self.logger.info( 'stopping blocking stats monitoring: ' + hostKey )

        if self.monitorConn is not None:
            self.monitorConn.disconnect()
            self.monitorConn = None

    def _collectStats( self, passes ):
        """ Make the call to mongo host and collect the blocking data """
        root = {}

        # Set the agent version and hostname.
        root['agentVersion'] = self.mmsAgent.agentVersion
        root['agentHostname'] = self.mmsAgent.agentHostname

        # Check occasionally to see if we can discover nodes
        isMaster = self.monitorConn.admin.command( 'ismaster' )
        root['isMaster'] = isMaster

        isMongos = ( isMaster.has_key( 'msg' ) and isMaster['msg'] == 'isdbgrid' )

        # Check to see if this is a mongod host
        try:
            if isMaster['ismaster'] == True and isMongos:
                # Look at the shards
                root['shards'] = list( self.monitorConn.config.shards.find() )

                root['locks'] = list( self.monitorConn.config.locks.find() )

                # Look at the mongos instances
                root['mongoses'] = list( self.monitorConn.config.mongos.find() )

                # Get the shard chunk counts.
                shardChunkCounts = []
                positions =  { }
                counter = 0

                if passes == 0 or passes % 10 == 0:
                    for chunk in self.monitorConn.config.chunks.find():
                        key = chunk['ns'] + chunk['shard']
                        if key not in positions:
                            count = {}
                            positions[key] = counter
                            shardChunkCounts.append( count )
                            counter = counter + 1
                            count['count'] = 0
                            count['ns'] = chunk['ns']
                            count['shard'] = chunk['shard']

                        shardChunkCounts[positions[key]]['count'] = shardChunkCounts[positions[key]]['count'] + 1

                    root['shardChunkCounts'] = shardChunkCounts
        except pymongo.errors.OperationFailure:
            pass

        root['serverStatus'] = self.monitorConn.admin.command( 'serverStatus' )

        isReplSet = False
        isArbiter = False

        if root['serverStatus'].has_key('repl'):
            #  Check to see if this is a replica set
            try:
                root['replStatus'] = self.monitorConn.admin.command( 'replSetGetStatus' )
                if root['replStatus']['myState'] == 7:
                    isArbiter = True

                isReplSet = True
            except pymongo.errors.OperationFailure:
                pass

            if isReplSet:
                oplog = "oplog.rs"
            else:
                oplog = "oplog.$main"

            localConn = self.monitorConn.local

            oplogStats = {}

            #  Get oplog status
            if isArbiter:
                # Do nothing for the time being
                pass
            elif isMaster['ismaster'] == True or isReplSet:
                try:
                    oplogStats["start"] = localConn[oplog].find( limit=1, sort=[ ( "$natural" , pymongo.ASCENDING ) ], fields={ 'ts' : 1 }  )[0]["ts"]

                    oplogStats["end"] = localConn[oplog].find( limit=1, sort=[ ( "$natural" , pymongo.DESCENDING ) ], fields={ 'ts' : 1} )[0]["ts"]

                    oplogStats['rsStats'] = localConn.command( {'collstats' : 'oplog.rs' } )

                except pymongo.errors.OperationFailure:
                    pass
            else:
                # Slave
                try:
                    oplogStats["sources"] = {}
                    for s in localConn.sources.find():
                        oplogStats["sources"][s["host"]] = s
                except pymongo.errors.OperationFailure:
                    pass

            root["oplog"] = oplogStats

        # Load the config.settings collection (balancer info etc.)
        if not isArbiter:
            try:
                root['configSettings'] = list( self.monitorConn.config.settings.find() )
            except Exception:
                pass

        # per db info - mongos doesn't allow calls to local
        root['databases'] = { }
        root['dbProfiling'] = { }
        root['dbProfileData'] = { }

        if ( passes == 0 or passes % 20 == 0 or self.hostDef['profiler'] ) and not isArbiter and not isMongos:
            for x in self.monitorConn.database_names():
                try:
                    if passes == 0 or passes % 20 == 0:
                        if self.slowDbStats and ( ( time.time() - self.lastDbStatsCheck ) < 14400000 ):
                            continue

                        if not self.mmsAgent.disableDbstats:
                            startTime = time.time()

                            temp = self.monitorConn[x].command( 'dbstats' )
                            # work around Python 2.4 and older bug
                            for f in temp:
                                # this is super hacky b/c of Python 2.4
                                if isinstance( temp[f] , (int, long, float, complex)) and str(temp[f]) == "-inf":
                                    temp[f] = 0
                            root['databases'][x] = temp

                            if ( time.time() - startTime ) > 4000:
                                self.slowDbStats = True
                            else:
                                self.slowDbStats = False

                            self.lastDbStatsCheck = time.time()

                    # If the profiler is enabled in MMS, collect data
                    if self.hostDef['profiler'] and not isArbiter:
                        try:
                            # Get the most recent entries.
                            profileData = list( self.monitorConn[x].system.profile.find( spec=None, fields=None, skip=0, limit=20, sort=[ ( "$natural", pymongo.DESCENDING ) ] ) )

                            if len( profileData ) > 0:
                                root['dbProfileData'][x] = profileData
                        except:
                            pass

                    # Check to see if the profiler is enabled
                    try:
                        profiling = self.monitorConn[x].command( { 'profile' : -1 } )
                        if profiling is not None and 'ok' in profiling:
                            del profiling['ok']
                        root['dbProfiling'][x] = profiling
                    except:
                        pass

                except:
                    continue

        if 'serverStatus' in root:
            del root['serverStatus']

        return root
