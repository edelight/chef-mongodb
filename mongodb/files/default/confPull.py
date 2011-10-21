"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

import threading, time, urllib2, traceback

try:
    import json
except ImportError:
    import simplejson as json

confPullAgentVersion = "1.3.7"

class ConfPullThread( threading.Thread ):
    """ The remote configuration pull thread object """

    def __init__( self, settings, mmsAgent):
        """ Initialize the object """
        self.settings = settings
        self.logger = mmsAgent.logger
        self.mmsAgent = mmsAgent

        self.confUrl = self.settings.config_url % {
            'key' : self.settings.mms_key,
            'hostname' :  self.mmsAgent.agentHostname,
            'sessionKey' : self.mmsAgent.sessionKey,
            'agentVersion' : self.mmsAgent.agentVersion
        }

        #self.logger.info(self.confUrl)

        threading.Thread.__init__( self )

    def run( self ):
        """ Pull the configuration from the cloud (if enabled) """
        uniqueHostnames = []

        while not self.mmsAgent.done:
            del uniqueHostnames[:]

            try:
                res = urllib2.urlopen( self.confUrl )

                resJson = None
                try :
                    resJson = json.loads( res.read() )
                finally:
                    if res is not None:
                        res.close()

                if 'hosts' not in resJson:
                    self.mmsAgent.stopAll()
                    time.sleep( self.mmsAgent.confInterval )
                    continue

                if 'disableDbstats' in resJson:
                    self.mmsAgent.disableDbstats = resJson['disableDbstats']
                else:
                    self.mmsAgent.disableDbstats = False

                hosts = resJson['hosts']

                self.mmsAgent.serverHostDefsLock.acquire()
                try:
                    # Extract the host information
                    if hosts is not None:
                        for host in hosts:
                            hostDef = self.mmsAgent.extractHostDef( host )
                            hostKey = hostDef['hostKey']
                            uniqueHostnames.append( hostKey )

                            if hostKey not in self.mmsAgent.serverHostDefs:
                                self.mmsAgent.startMonitoringThreads( hostDef )
                            else:
                                self.mmsAgent.checkChangedHostDef( hostDef )

                    # Check to see if anything was removed
                    for hostDef in self.mmsAgent.serverHostDefs.values():
                        if hostDef['hostKey'] not in uniqueHostnames:
                            self.mmsAgent.stopAndClearHost( hostDef['hostKey'] )
                finally:
                    self.mmsAgent.serverHostDefsLock.release()

                del uniqueHostnames[:]

            except Exception, e:
                self.logger.warning( "Problem pulling configuration data from MMS (check firewall and network): " +  traceback.format_exc( e ) )

            time.sleep( self.mmsAgent.confInterval )

