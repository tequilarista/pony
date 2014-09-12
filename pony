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

PONY_CONF_FILE = os.path.join(os.environ['HOME'],'.pony.conf')
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
    def __init__(self, customer, comment, userAuth, userPassword, server, project, duration=None):
        """ 
        :param customer -- person we are recording having helped
        :param comment -- brief description of task
        :param userAuth -- authenticating user for jira connection
        :param userPassword -- password for above
        :param server -- jira server URL 
        :param project -- name of jira project
        :param duration -- optional notation of time spent, jira notation
        """
        self.serverConn = None
        self.serverURL = server
        self.serverAuth = userAuth
        self.serverPassword = userPassword

        # ticken info
        self.verbose = False
        self.jiraProj = project
        self.customer = customer
        self.comment = comment
        self.duration = duration

        if os.environ['USER']:
            self.assignee = os.environ['USER']
        else:
            self.assignee = self.serverAuth

    def printError(self, msg, exception=None):
            print "_ERROR_\n%s" % msg
            if exception:
                print "Exception:\n---------\n %s\n---------" % exception

    def generateTicketURL(self,id):
        urlPath = "%s/browse/%s" % (self.serverURL, id)
        return urlPath

    def _createConnection(self):
        jira_server = {'server': self.serverURL}
        jira_auth = (self.serverAuth,self.serverPassword)
        try:
            self.serverConn = JIRA(options=jira_server,basic_auth=jira_auth)
        except Exception, e:
            self.printError("Unable to create connection to JIRA", e)
            return False

        return True
            

    def createTicket(self, jiraSummary):
        self._createConnection()

        fields = {"project": {"key": self.jiraProj },
                  "summary": jiraSummary,
                  "issuetype": {"name": "Bug"},
                  "labels": ['HelpTicket']
                 }
        try:
            new_id = self.serverConn.create_issue(fields)
            self.serverConn.assign_issue(new_id, self.assignee)
            return new_id
        except Exception, e:
            self.printError("Unable to create ticket", e)

        return True
            

    def closeTicket(self,id):
        # obscure, but the API wants you to know the "transitionID" for closing a bug.  According to my
        # spelunking, it's 2.  Clear as mud.
        try:
            self.serverConn.transition_issue(id, transitionId=2)
        except Exception, e:
            self.printError("Unable to close ticket id=%s" % id, e)
            return False

        return True


    def addWorkDuration(self, id):
        """
        For a specified JIRA issue, log work as specified
        by the 'duration' user argument

        :param -- JIRA issue id
        """
        try:
            self.serverConn.add_worklog(issue=id,timeSpent=self.duration)
        except Exception, e:
            self.printError("Unable to update ticket id=%s with duration information" % id, e)
            return False
            
        return True


    def LogTicketAndClose(self):
        """
        Given a customer name and a comment, creates then immediately
        closes a help ticket in JIRA
        """
        # first create the ticket
        jiraSummary = "%s requested help with: %s" % (self.customer, self.comment)
        id = self.createTicket(jiraSummary)
        if not id:
            return False


        # if duration was specified, log that now
        if self.duration:
            if not self.addWorkDuration(id):
                return False

        # now close it out
        if not self.closeTicket(id):
                return False

        return id


##############################
def main():

    parser = optparse.OptionParser()

    parser.add_option("-u",
                      metavar="<customer>",
                      dest="customer",
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

    if not (options.customer or options.comment):
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


    # instantiate class
    p = Pony(options.customer, options.comment, userAuthArg, passAuthArg, serverArg, projectArg, options.duration)

    # stable it
    ticketID = p.LogTicketAndClose()
    if ticketID:
        ticketURL = p.generateTicketURL(ticketID)
        print "Successfully stabled that pony!: %s" % ticketURL
        sys.exit(0)
    else:
        sys.exit("Successfully stabled that pony!: %s" % ticketURL)

if __name__ == "__main__":
    main()

