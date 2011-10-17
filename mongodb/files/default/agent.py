"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# App
import settings as _settings
import logConfig

# Python
import sys, socket, time, os, hmac, urllib2, threading, subprocess, traceback

try:
    import hashlib
except ImportError:
    sys.exit('ERROR - you must have hashlib installed - see README for more info' )

_logger = logConfig.initLogger()

socket.setdefaulttimeout( _settings.socket_timeout )

_pymongoVersion = None

_processPid = os.getpid()

# Try and reduce the stack size.
try:
    threading.stack_size(409600)
except:
    pass

if _settings.mms_key == '@API_KEY@':
    sys.exit( 'ERROR - you must set your @API_KEY@ - see https://mms.10gen.com/settings' )

if _settings.secret_key == '@SECRET_KEY@':
    sys.exit( 'ERROR - you must set your @SECRET_KEY@ - see https://mms.10gen.com/settings' )

if sys.version_info < ( 2, 4 ):
    sys.exit( 'ERROR - old Python - the MMS agent requires Python 2.4 or higher' )

# Check to see if we can use the core json library
try:
    import json
except ImportError:
    try:
        import simplejson as json
    except ImportError:
        sys.exit('ERROR - old Python with no json support - please install simplejson - easy_install simplejson')

# Make sure pymongo is installed
try:
    import pymongo
    import bson
except ImportError:
    sys.exit( 'ERROR - pymongo not installed - see: http://api.mongodb.org/python/ - run: easy_install pymongo' )

# Check the version of pymongo.
pyv = pymongo.version
if "partition" in dir( pyv ):
    pyv = pyv.partition( "+" )[0]
    _pymongoVersion = pyv
    if map( int, pyv.split('.') ) < [ 1, 9]:
        sys.exit("ERROR - The MMS agent requires pymongo 1.9 or higher: easy_install -U pymongo")

_pymongoVersion = pymongo.version

class AgentProcessContainer( object ):
    """ Store the handle and lock to the agent process. """

    def __init__( self ):
        """ Init the lock and init process to none """
        self.lock = threading.Lock()
        self.agent = None

    def pingAgentProcess( self ):
        """ Ping the agent process """
        try:
            self.lock.acquire()

            if self.agent is None or self.agent.poll() is not None:
                return

            self.agent.stdin.write( 'hello\n' )
            self.agent.stdin.flush()
        finally:
            self.lock.release()

    def stopAgentProcess( self ):
        """ Send the stop message to the agent process """
        try:
            self.lock.acquire()

            if self.agent is None or self.agent.poll() is not None:
                return

            self.agent.stdin.write( 'seeya\n' )
            self.agent.stdin.flush()

            time.sleep( 1 )
            self.agent = None

        finally:
            self.lock.release()

class AgentProcessMonitorThread( threading.Thread ):
    """ Make sure the agent process is running """

    def __init__( self, logger, agentDir, processContainerObj ):
        """ Initialize the object """
        self.logger = logger
        self.agentDir = agentDir
        self.processContainer = processContainerObj
        threading.Thread.__init__( self )

    def _launchAgentProcess( self ):
        """ Execute the agent process and keep a handle to it. """

        return subprocess.Popen( [ sys.executable, os.path.join( sys.path[0], 'agentProcess.py' ), str( _processPid ) ], stdin=subprocess.PIPE, stdout=subprocess.PIPE )

    def run( self ):
        """ If the agent process is not alive, start the process """
        while True:
            try:
                time.sleep( 5 )

                self.processContainer.lock.acquire()
                try:
                    if self.processContainer.agent is None or self.processContainer.agent.poll() is not None:
                        self.processContainer.agent = self._launchAgentProcess()
                except Exception, e:
                    self.logger.error( traceback.format_exc( e ) )
            finally:
                self.processContainer.lock.release()

class AgentUpdateThread( threading.Thread ):
    """ Check to see if updates are available - if so download and restart agent process """

    def __init__( self, logger, agentDir, settingsObj, processContainerObj ):
        """ Initialize the object """
        self.logger = logger
        self.agentDir = agentDir
        self.settings = settingsObj
        self.processContainer = processContainerObj
        threading.Thread.__init__( self )

    def run( self ):
        """ Update the agent if possible """
        while True:
            try:
                time.sleep( 300 )

                res = None
                resJson = None
                res = urllib2.urlopen( self.settings.version_url % { 'key' : self.settings.mms_key } )
                try :
                    resJson = json.loads( res.read() )
                finally:
                    if res is not None:
                        res.close()

                if 'status' not in resJson or resJson['status'] != 'ok':
                    continue

                if 'agentVersion' not in resJson or 'authCode' not in resJson:
                    continue

                agentVersion = resJson['agentVersion']
                authCode =  resJson['authCode']

                if authCode != hmac.new( self.settings.secret_key, agentVersion, digestmod=hashlib.sha1 ).hexdigest():
                    self.logger.error( 'Invalid auth code' )
                    continue

                if agentVersion != self.settings.settingsAgentVersion:
                    self._upgradeAgent( agentVersion )

            except Exception, e:
                self.logger.error( traceback.format_exc( e ) )

    def _upgradeAgent( self, newAgentVersion ):
        """ Pull down the files, verify  and then stop the current process """
        resJson = None
        res = urllib2.urlopen( self.settings.upgrade_url % { 'key' : self.settings.mms_key } )
        try :
            resJson = json.loads( res.read() )
        finally:
            if res is not None:
                res.close()

        if 'status' not in resJson or resJson['status'] != 'ok' or 'files' not in resJson:
            return

        # Verify the auth codes for all files and names first.
        for fileInfo in resJson['files']:
            if fileInfo['fileAuthCode'] != hmac.new( self.settings.secret_key, fileInfo['file'], digestmod=hashlib.sha1 ).hexdigest():
                self.logger.error( 'Invalid file auth code for upgrade - cancelling' )
                return

            if fileInfo['fileNameAuthCode'] != hmac.new( self.settings.secret_key, fileInfo['fileName'], digestmod=hashlib.sha1 ).hexdigest():
                self.logger.error( 'Invalid file name auth code for upgrade - cancelling' )
                return

        # Write the files.
        for fileInfo in resJson['files']:
            fileName = fileInfo['fileName']
            fileSystemName = os.path.join( self.agentDir, fileName )
            newFile = open( fileSystemName, 'w')
            try:
                newFile.write( fileInfo['file'] )
            finally:
                if newFile is not None:
                    newFile.close()

        # Stop the current agent process
        try:
            self.processContainer.stopAgentProcess()
            self.settings.settingsAgentVersion = newAgentVersion
        except Exception, e:
            self.logger( 'Problem restarting agent process: ' + str( e ) )

#
# Run the process monitor and update threads.
#
if __name__ == "__main__":
    try:

        _logger.info( 'Starting agent parent process' )
        processContainer = AgentProcessContainer()

        # Star the agent monitor thread.
        monitorThread = AgentProcessMonitorThread( _logger, sys.path[0], processContainer )
        monitorThread.setName( 'AgentProcessMonitorThread' )
        monitorThread.setDaemon( True )
        monitorThread.start()

        if _settings.autoUpdateEnabled:
            updateThread = AgentUpdateThread( _logger, sys.path[0], _settings, processContainer )
            updateThread.setName( 'AgentUpdateThread' )
            updateThread.setDaemon( True )
            updateThread.start()

        _logger.info( 'Started agent parent process' )

        # The parent process will let the child process know it's alive.
        while True:
            try:
                time.sleep( 2 )
                processContainer.pingAgentProcess()
            except Exception, exc:
                _logger.error( traceback.format_exc( exc ) )

    except KeyboardInterrupt:
        processContainer.stopAgentProcess()
    except Exception, ex:
        _logger.error( traceback.format_exc( ex )  )

