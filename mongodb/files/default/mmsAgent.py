"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# App
import munin, nonBlockingStats, blockingStats

# Mongo
import bson

# Python
import threading, urllib2, socket, zlib, time

mmsAgentVersion = "1.3.7"

class MmsAgent( object ):
    """ The mms agent object """

    def __init__( self, settings, agentVersion, pythonVersion, pymongoVersion, agentHostname, logger, sessionKey ):
        """ Constructor """
        self.logger = logger

        self.sessionKey = sessionKey

        self.settings = settings

        self.pythonVersion = pythonVersion
        self.pymongoVersion = pymongoVersion
        self.agentHostname = agentHostname
        self.agentVersion = agentVersion

        self.collectionInterval = settings.collection_interval
        self.confInterval  = settings.conf_interval

        self.hostStateLock = threading.Lock()
        self.hostState = { }
        self.hostStateLastUpdate = { }

        self.serverHostDefs = { }
        self.serverHostDefsLock = threading.Lock()

        self.serverUniqueHosts = { }
        self.serverUniqueHostsLock = threading.Lock()

        self.pingUrl = settings.ping_url % settings.mms_key

        self.disableDbstats = False

        self.done = False

        socket.setdefaulttimeout( settings.socket_timeout )

    def haveHostDef( self, hostKey ):
        """ Returns true if this is a known host """
        self.serverHostDefsLock.acquire()
        try:
            return hostKey in self.serverHostDefs
        finally:
            self.serverHostDefsLock.release()

    def _removeHostState( self, hostKey ):
        """ Delete the state for a host """
        self.hostStateLock.acquire()
        try:
            if hostKey in self.hostState:
                del self.hostState[hostKey]
        finally:
            self.hostStateLock.release()

    def _extractHostname( self, hostKey ):
        """ Extract the hostname from the hostname:port hostKey """
        return hostKey[0 : hostKey.find( ':' )]

    def _extractPort( self, hostKey ):
        """ Extract the port from the hostname:port hostKey """
        return int( hostKey[ ( hostKey.find(':' ) + 1 ) : ] )

    def setMuninHostState( self, hostname, state ):
        """ Set the state inside of the lock - there are multiple threads who set state here """
        if state is None:
            return

        try:
            self.hostStateLock.acquire()

            for hostKey in self.hostState.keys():
                if hostname == self._extractHostname( hostKey ):
                    state['port'] = self._extractPort( hostKey )
                    self._setHostStateValue( hostKey, 'munin', state )
        finally:
            self.hostStateLock.release()

    def cleanHostState( self ):
        """ Make sure the host state data is current """
        try:
            self.hostStateLock.acquire()
            now = time.time()

            toDel = []

            for hostKey in self.hostState:
                if hostKey not in self.hostStateLastUpdate:
                    continue

                if ( now - self.hostStateLastUpdate[hostKey] ) > 60:
                    toDel.append( hostKey )

            for hostKey in toDel:
                del self.hostState[hostKey]

        finally:
            self.hostStateLock.release()

    def setHostState( self, hostKey, stateType, state ):
        """ Set the state inside of the lock - there are multiple threads who set state here """
        if state is None:
            return

        try:
            self.hostStateLock.acquire()
            self._setHostStateValue( hostKey, stateType, state )
        finally:
            self.hostStateLock.release()

    def _setHostStateValue( self, hostKey, stateType, state):
        """ Set the host state. This can only be called when a host state lock is in place """

        if hostKey not in self.hostState:
            self.hostState[hostKey] = { }

        self.hostState[hostKey][stateType] = bson.binary.Binary( zlib.compress( bson.BSON.encode( state, check_keys=False ), 9 ) )
        self.hostStateLastUpdate[hostKey] = time.time()

    def checkChangedHostDef( self, hostDef ):
        """ Check to see if this host definition has changed. If it has, stop the thread and
        start a new one. This assumes it is called inside of serverHostDefsLock """

        hostKey = hostDef['hostKey']

        if hostDef['mongoUri'] == self.serverHostDefs[hostKey]['mongoUri']:
            return

        self.stopAndClearHost( hostKey )

        # Start the new thread and set the host def.
        self.startMonitoringThreads( hostDef )

    def startMonitoringThreads( self, hostDef ):
        """ Start server status and munin threads. This assumes it is called inside of serverHostDefsLock """

        hostKey = hostDef['hostKey']

        # Start the non-blocking stats thread
        hostDef['nonBlockingStatsThread'] = nonBlockingStats.NonBlockingMongoStatsThread( hostDef, self )
        hostDef['nonBlockingStatsThread'].setName( ( 'NonBlockingMongoStatsThread-' + hostKey ) )
        hostDef['nonBlockingStatsThread'].start()

        # Start the blocking stats thread
        hostDef['blockingStatsThread'] = blockingStats.BlockingMongoStatsThread( hostDef, self )
        hostDef['blockingStatsThread'].setName( ( 'BlockingMongoStatsThread-' + hostKey ) )
        hostDef['blockingStatsThread'].start()

        # Start the munin thread for the server, if there is not one running.
        self._startMuninThread( hostDef['hostname'] )

        # Start the munin thread if there is not one running.
        self.serverHostDefs[hostDef['hostKey']] = hostDef

    def _startMuninThread( self, hostname ) :
        """ Start the munin thread if one is not running """
        try:
            self.serverUniqueHostsLock.acquire()
            if hostname not in self.serverUniqueHosts:
                self.serverUniqueHosts[hostname] = munin.MuninThread( hostname, self )
                self.serverUniqueHosts[hostname].setName( ( 'MuninThread-' + hostname ) )
                self.serverUniqueHosts[hostname].start()
        finally:
            self.serverUniqueHostsLock.release()

    def hasUniqueServer( self, hostname ):
        """ Return true if there hostname is in the list """
        try:
            self.serverUniqueHostsLock.acquire()
            return hostname in self.serverUniqueHosts
        finally:
            self.serverUniqueHostsLock.release()

    def extractHostDef( self, host ):
        """ Return an array of host tuples found in the uri, username and password (hosts, username, password) """

        hostKey = host['hostKey']

        # Check to see if we already have this object.
        if hostKey not in self.serverHostDefs:
            hostDef = { }
            hostDef['hostname'] = host['hostname']
            hostDef['id'] = host['id']
            hostDef['hostKey'] = host['hostKey']
            hostDef['port'] = host['port']
            hostDef['threadRunning'] = True
        else:
            self.serverHostDefs[hostKey]['profiler'] = host['profiler']
            self.serverHostDefs[hostKey]['munin'] = host['munin']
            hostDef = self.serverHostDefs[hostKey].copy()

        hostDef['mongoUri'] = host['uri']
        hostDef['munin'] = host['munin']
        hostDef['profiler'] = host['profiler']

        if 'username' in host:
            hostDef['username'] = host['username']
        else:
            hostDef['username'] = None

        if 'password' in host:
            hostDef['password'] = host['password']
        else:
            hostDef['password'] = None

        return hostDef

    def isValidMonitorConn( self, hostDef, conn ):
        """ In pymongo <= 1.9, even with slave_okay set, we will re-route to master if the secondary we're talking to goes down - this should work around that """
        if not conn:
            return False

        if conn.host is not None:
            if conn.host != hostDef['hostname'] or str( conn.port ) != str( hostDef['port'] ):
                self.logger.warning( 'replica set switched hosts, disconnecting - wanted: ' + str( hostDef['mongoUri'] ) + ' - got: mongodb://' + str( conn.host ) + ':' + str( conn.port ) )
                if conn is not None:
                    conn.disconnect()
                conn = None
                return False
            else:
                return True
        else:
            return True

    def _handleRemote( self, req ):
        """ Send the data to the central MMS servers """
        try:
            if req is None:
                return

            res = None

            try:
                res = urllib2.urlopen( self.pingUrl, req )
                res.read()
            finally:
                if res is not None:
                    res.close()

        except Exception:
            self.logger.warning( "Problem sending data to MMS (check firewall and network)" )

    def _assemblePingRequest( self ):
        """ Create the ping data request """
        try:
            if self.hostState is None:
                return None

            req = { 'key' : self.settings.mms_key , 'hosts' : self.hostState }

            req['agentVersion'] = self.agentVersion
            req['agentHostname'] = self.agentHostname
            req['pythonVersion'] = self.pythonVersion
            req['pymongoVersion'] = self.pymongoVersion
            req['dataFormat'] = 1

            return bson.BSON.encode( req, check_keys=False )
        finally:
            self.hostState.clear()

    def sendDataToMms( self ):
        """ Copy and convert the data and send to MMS """
        data = None

        try:
            self.hostStateLock.acquire()
            # Empty dictionary is False
            #if self.hostState:
            if ( self.hostState is not None and len( self.hostState ) > 0 ):
                data = self._assemblePingRequest()
        finally:
            self.hostStateLock.release()

        if data is None:
            return

        self._handleRemote( data )

    def stopAll( self ):
        """ Stop all the threads """
        try:
            self.serverHostDefsLock.acquire()
            for hostKey in self.serverHostDefs.keys():
                self.stopAndClearHost( hostKey )
        finally:
            self.serverHostDefsLock.release()

    def stopAndClearHost( self, hostKey ):
        """ Stop the data collection for this host. This assumes a server host def lock """

        if hostKey not in self.serverHostDefs:
            return

        self._removeHostState( hostKey )

        # Check and see if this is the last definition of the unique server
        self._stopAndClearUniqueHost( self.serverHostDefs[hostKey]['hostname'] )

        # Stop the current thread and delete the definition
        self.serverHostDefs[hostKey]['threadRunning'] = False

        # Remove the object from the dictionary.
        del self.serverHostDefs[hostKey]

    def _stopAndClearUniqueHost( self, hostname ):
        """ If this is the last reference to a hostname, remove. This requires a host def lock wrapping """
        try:
            self.serverUniqueHostsLock.acquire()

            foundCount = 0

            for hostKey in self.serverHostDefs.keys():
                if self.serverHostDefs[hostKey]['hostname'] == hostname:
                    foundCount = foundCount + 1

            if foundCount <= 1 and hostname in self.serverUniqueHosts:
                self.serverUniqueHosts[hostname].stopThread()
                del self.serverUniqueHosts[hostname]
        finally:
            self.serverUniqueHostsLock.release()
