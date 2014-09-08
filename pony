#!/usr/bin/python
"""
pony: tool for fast logging of JIRA tasks
__author__ = 'Tara Hernandez'
__version__ = '3.0'

requirements: 
    jira module

"""

import json
import optparse
import os
import re
import subprocess
import sys

from jira.client import JIRA # pip install jira

PONY_CONF_FILE = os.path.join(os.environ['HOME'],'.newpony.conf')
if os.path.exists(PONY_CONF_FILE):
    execfile(PONY_CONF_FILE)

def createTemplate():
    ponyTemplate = { 'login_info': {
                                    'serverURL': "<HTTP Url for bug system>",
                                    'project' : "<project code>",
                                    'userAuth': "<your username>",
                                    'passAuth': "<your password>",
                                    }
                    }

    if os.path.exists(PONY_CONF_FILE):
        answer = None
        while not answer:
            answer = raw_input("~/.pony.conf already exists, overwrite? [y/n]")
            if answer.lower() == "n":
                return False

    fh = open(PONY_CONF_FILE, "w+")
    dump = json.dumps(ponyTemplate, indent=4, sort_keys=False)
    fh.write(dump)
    fh.close()
    return True

def loadTemplate():
    try:
        fh = open(PONY_CONF_FILE, 'r')
        res = json.loads(fh.read())
        fh.close()
    except IOError, e:
       print "Unable to load %s" % PONY_CONF_FILE

    user = res['login_info']['userAuth']
    passwd = res['login_info']['passAuth']
    srvr = res['login_info']['serverURL']
    proj = res['login_info']['project']
    return (user,passwd,srvr,proj)

class Pony():
    """ Pony class -- provides helper and task functions to talk to a bug server (jira, right now"""
    def __init__(self, user, comment, userAuth, userPassword, server, project, duration=None):
        """ class attrs:
        user -- person we are recording having helped
        comment -- brief description of task
        duration -- optional notation of time spent
        verbose -- XXX debug info?
        """
        self.serverConn = None
        self.serverURL = None
        self.serverAuth = None
        self.serverPassword = None

        # ticken info
        self.verbose = False
        self.jiraProj = project
        self.user = user
        self.comment = comment
        self.duration = duration

    def _createConnection(self):
        jira_server = {'server': self.serverURL}
        jira_auth = (self.serverAuth,self.serverPassword)
        try:
            self.serverConn = JIRA(options=jira_server,basic_auth=jira_auth)
        except Exception, e:
            print "Unable to create connection to JIRA: %s", e
            raise


    def createTicket(self, jiraSummary):
        self._createConnection()
        new_id = self.serverConn.create_issue(project={'key': self.jiraProj}, summary=self.comment,
                              issuetype={'name': 'task'})
        self.serverConn.assign_issue({'issue':new_id,'assignee':self.serverAuth})
        return new_id

    def closeTicket(self,id):
        self.serverConn.transition_issue(fields={'issue' : id,
                                                'status' : 'Closed',
                                                'resolution':'Done'})

    def addWorkDuration(self, id):
        """
        For a specified JIRA issue, log work as specified
        by the 'duration' user argument

        @input -- JIRA issue id
        @output -- True for success, False otherwise
        """

        self.serverConn.add_worklog(issue=id,timeSpent=self.duration)

        return True # XXX ?

    def LogTicketAndClose(self):
        """
        Given a user name and a comment, create then immediately
        closes a help ticket in JIRA
        """
        # first create the ticket
        jiraSummary = "%s requested help with: %s" % (self.user, self.comment)
        id = self.createTicket(jiraSummary).strip()

        # if duration was specified, log that now
        if self.duration:
            log = self.addWorkDuration(id)
            if not log:
                print "ERROR: failed to log work timeSpent '%s' to %s" % (self.duration, id)

        # now close it out
        res = self.closeTicket(id)
        if res:
            print "HelpTicket %s succesfully logged!" % id
        else:
            print "ERROR: failed to close issue: %s" % (id)


##############################
def main():

    parser = optparse.OptionParser()

    parser.add_option("-u",
                      metavar="<user>",
                      dest="user",
                      help="name of user needing assistance -- REQUIRED.")
    parser.add_option("-c",
                      metavar="<comment>",
                      dest="comment",
                      help="brief description of the task, will be used as the "
                           "bug summary -- REQUIRED.")
    parser.add_option("-d",
                      metavar="<duration>",
                      dest="duration",
                      help="amount of time spent, i.e.: 2h, 3d, 1w -- OPTIONAL")
    parser.add_option("-a",
                      metavar="<serverAuth>",
                      dest="serverAuth",
                      help="Name of person logging ticket, to use as credentials to bug system -- REQUIRED (but can be set in template)")
    parser.add_option("-p",
                      metavar="<password>",
                      dest="password",
                      help="Password to go with -e option -- REQUIRED (but can be set in template.")
    parser.add_option("-s",
                      metavar="<serverURL>",
                      dest="serverURL",
                      help="HTTP URL to bug system -- REQUIRED (but can be set in template.")
    parser.add_option("-x",
                      metavar="<project>",
                      dest="project",
                      help="JIRA project code")
    parser.add_option("-t",
                      metavar="<template>",
                      dest="template",
                      action = "store_true",
                      help="Run 'pony -t' to create ~/.pony.conf template file to store server info")
    options, args = parser.parse_args()

    # keeps things clean for now, in the future we may want to expand the number
    # of tasks this script can do
    if args:
        parser.error("This program does not accept the following as "
                     "arguments: %s" % str(args))

    # if we're just dumping the template, do it now
    if options.template:
        res = createTemplate()
        if not res:
            sys.exit("Can't create template. Exiting...")
        sys.exit("Template file created at %s" % PONY_CONF_FILE)

    if not (options.user or options.comment):
        parser.error("ERROR: Missing required options.  Please run "
             "'pony -h' for usage")

    userAuthArg = ""
    passAuthArg = ""
    serverArg = ""
    projectArg = ""
    if (options.serverAuth and options.password and options.serverURL and options.project):
        userAuthArg = options.serverAuth
        passAuthArg = options.password
        serverArg = options.serverURL
        projectArg = options.project
    elif os.path.exists(PONY_CONF_FILE):
        (userAuthArg, passAuthArg, serverArg, projectArg) = loadTemplate()
    else:
        parser.error("ERROR: Missing required options.  Please run "
             "'pony -h' for usage")

    print options.user, options.comment, userAuthArg, passAuthArg, serverArg, projectArg, options.duration

    sys.exit()

    # instantiate class
    p = Pony(options.user, options.comment, userAuthArg, passAuthArg, serverArg, projectArg, options.duration)
    p.LogTicketAndClose()

if __name__ == "__main__":
    main()

