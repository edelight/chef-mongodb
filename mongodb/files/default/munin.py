"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# Python
import socket, threading, time

muninAgentVersion = "1.3.7"

def containsStr( val, query ):
    """ Returns true if the value is contained in the string """
    return val.find( query ) > -1

class MuninThread( threading.Thread ):
    """ Pull them munin data from the various hosts. """

    def __init__( self, hostname, mmsAgent ):
        """ Initialize the object """
        self.hostname = hostname
        self.mmsAgent = mmsAgent
        self.logger = mmsAgent.logger
        self.muninNode = MuninNode( self.hostname )
        self.running = True
        threading.Thread.__init__( self )

    def run( self ):
        """ Pull the munin data from the various hosts. """

        self.logger.info( 'starting munin monitoring: ' + self.hostname + ':4949' )

        sleepTime = ( self.mmsAgent.collectionInterval / 2 ) - 1

        if ( sleepTime < 1 ):
            sleepTime = 1

        while not self.mmsAgent.done and self.mmsAgent.hasUniqueServer( self.hostname ) and self.running:
            try:
                time.sleep( sleepTime )
                self._collectAndSetState()
            except:
                pass

        self.logger.info( 'stopping munin monitoring: ' + self.hostname + ':4949' )

    def stopThread( self ):
        """ Stop the thread. This sets a running flag to false """
        self.running = False

    def _collectAndSetState( self ):
        """ Collect the data and set the state """
        muninStats = self._collectStats()

        if muninStats is None:
            return

        muninStats['host'] = self.hostname

        self.mmsAgent.setMuninHostState( self.hostname, muninStats )

    def _collectStats( self ):
        """ Collect the data from the munin host """
        try:
            return self.muninNode.fetchAndConfigMany( [ "cpu" , "iostat" , "iostat_ios" ] )
        except:
            return None

class MuninNode( object ):
    """ The Munin node collection object """

    def __init__( self, host='127.0.0.1', port=4949 ):
        """ Constructor """
        self.host = host
        self.port = port
        self.sock = None
        self.f = None

    def _send( self, cmd):
        """ Send a command to Munin """
        self.sock.send( cmd + "\r\n" )

    def _readline( self ):
        """ Read data from Munin """
        return self.f.readline().split("\n")[0]

    def list( self ):
        """ Run a list operation """
        self._send( 'list' )
        s = self._readline()

        return s.split( ' ' )

    def config( self, cmd ):
        """ Run a config operation """
        return self._data( 'config', cmd )

    def fetch( self, cmd ):
        """ Run a fetch operation """
        return self._data( 'fetch', cmd )

    def _data(  self, cmdType, cmd ):
        """ Collect data """
        self._send( cmdType + ' ' + cmd )
        data = []
        while True:
            s = self._readline()
            if s == ".":
                break

            if cmdType == 'config':
                if containsStr( s, '.label' ) == False:
                    continue

            data.append( s )
        return data

    def connect( self ):
        """ Connect to the Munin node """
        self.sock = None
        self.f = None
        self.sock = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
        self.sock.connect( ( self.host, self.port ) )

        self.f = self.sock.makefile()

        if not self.f:
            raise Exception( 'Error reading data from socket' )

        banner = self.f.readline() # banner

        if len( banner ) == 0:
            self.sock = None
            self.f = None
            raise Exception( 'Unable to connect to Munin' )

    def disconnect( self ):
        """ Disconnect from Munin """
        try:
            try:
                self._send( 'quit' )
            finally:
                self.sock.close()
        finally:
            if self.f is not None:
                self.f.close()
                self.f = None

        self.sock = None

    def fetchAndConfigMany( self, cmdTypes ):
        """ The fetch and config many cmds - opens and closes the connection """
        try:
            self.connect()
            fetch = {}
            config = {}
            for t in cmdTypes:
                fetch[t] = self.fetch( t )

                if ( t == 'cpu' ):
                    config[t] = { }
                else:
                    config[t] = self.config( t )

            return { 'fetch': fetch, 'config': config }
        finally:
            try:
                self.disconnect()
            except:
                pass

