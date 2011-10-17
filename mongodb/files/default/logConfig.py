"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# App
import settings as _settings

# Mongo
import pymongo

# Python
import logging, threading, time, logging.handlers, urllib, urllib2, platform, socket, traceback, Queue

try:
    import json
except ImportError:
    import simplejson as json

socket.setdefaulttimeout( _settings.socket_timeout )

class LogRelayThread( threading.Thread ):
    """ The log relay thread - batch messages """

    def __init__( self, recordQueue ):
        """ Construct the object """
        self.recordQueue = recordQueue
        self.logUrl = _settings.logging_url % { 'key' : _settings.mms_key }
        self.pythonVersion = platform.python_version()

        try:
            self.hostname = platform.uname()[1]
        except:
            self.hostname = 'UNKNOWN'

        self.pymongoVersion = pymongo.version
        threading.Thread.__init__( self )

    def run( self ):
        """ The agent process """
        while True:
            try:
                records = []

                # Let the records batch for five seconds
                time.sleep( 5 )
                try:
                    while not self.recordQueue.empty():
                        record = self.recordQueue.get()

                        if record is None:
                            continue

                        data = { }
                        data['levelname'] = record.levelname
                        data['msg'] = record.msg
                        data['filename'] = record.filename
                        data['threadName'] = record.threadName

                        # This is to deal with older versions of python.
                        try:
                            data['funcName'] = record.funcName
                        except:
                            pass

                        data['process'] = record.process
                        data['lineno'] = record.lineno
                        data['pymongoVersion'] = self.pymongoVersion
                        data['pythonVersion'] = self.pythonVersion
                        data['hostname'] = self.hostname

                        records.append( data )

                except Queue.Empty:
                    pass

                if len( records ) == 0:
                    continue

                # Send the data back to mms.
                res = None
                try:
                    res = urllib2.urlopen( self.logUrl, ( '{ "records" : ' + json.dumps( records ) + '}' ) )
                    res.read()
                finally:
                    if res is not None:
                        res.close()

            except Exception, ex:
                print( traceback.format_exc( ex ) )

class MmsRemoteHandler( logging.Handler ):
    """ The mms remote log handler """
    def __init__( self ):
        """ Construct a new object """
        logging.Handler.__init__( self )
        self.recordQueue = Queue.Queue( 0 )
        self.logRelay = LogRelayThread( self.recordQueue )
        self.logRelay.setName( 'LogRelay' )
        self.logRelay.start()

    def emit( self, record ):
        """ Send the record to the remote servers """
        try:
            if record is not None:
                self.recordQueue.put_nowait( record )
        except Exception, ex:
            print( traceback.format_exc( ex ) )

def initLogger( ):
    """ Initialize the logger """
    logger = logging.getLogger('MMS')
    streamHandler = logging.StreamHandler()
    streamHandler.setFormatter( logging.Formatter('%(asctime)s %(levelname)s %(message)s') )
    logger.addHandler( streamHandler )
    logging.handlers.MmsRemoteHandler = MmsRemoteHandler
    logger.addHandler( logging.handlers.MmsRemoteHandler() )
    logger.setLevel( logging.INFO )
    return logger

