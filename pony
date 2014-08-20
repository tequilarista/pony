#!/usr/bin/python
"""
pony: tool for fast logging of JIRA tasks
__author__ = 'Tara Hernandez'
__version__ = '2.0'

requirements: needs to have access to the JIRA cli tool.  Easiest way is to create
a conf file:

    ~/.pony.conf

and add the following line:

    JIRA_CMD = "/path/to/jira.sh"

You can also set JIRA_CMD as an environment variable.

"""

import optparse
import os
import re
import subprocess
import sys

# "Where's jira?" -- check for a conf file that will
# specify the jira path
JIRA_CMD = ""
PONY_CONF_FILE = os.path.join(os.environ['HOME'],'.pony.conf')
if os.path.exists(PONY_CONF_FILE):
    execfile(PONY_CONF_FILE)

# didn't find one, what else we got?
if not JIRA_CMD:
    if os.environ.has_key("JIRA_CMD"):
        JIRA_CMD = os.environ["JIRA_CMD"]
    elif os.path.exists(os.path.join(os.path.dirname(sys.argv[0]),"jira-cli-3.6.0/jira.sh")):
        JIRA_CMD = os.path.join(os.path.dirname(sys.argv[0]),"jira-cli-3.6.0/jira.sh")
    else:
        sys.exit("Sorry, can't find a jira CLI to run")


class Pony():
    """ Pony class -- provides helper and task functions to talk to JIRA"""
    def __init__(self, user, comment, duration=None, verbose=False):
        """ class keywords:
        user -- person we are recording having helped
        comment -- brief description of task
        duration -- optional notation of time spent
        verbose -- tell JIRA cli to dump debug data
        """
        self.verbose = verbose
        self.user = user
        self.comment = comment
        self.duration = duration
    
        try:
            self.assignee = os.environ['USER']
        except Exception, e:
            sys.exit("Unable to determine $USER value")

    def _runJIRACmd(self, cmdOpts):
        """
        execute jira cli command.

        input -- list of arguments to pass to jira
        @output -- raw list returned by subprocess call
        """
        cmdList = [JIRA_CMD] + cmdOpts
        if self.verbose:
            cmdList.append("--debug")
            print "+++++++++++++++"
            print "Command run:"
            print " ".join(cmdList)
            print "+++++++++++++++"
        try:
            res = subprocess.Popen(cmdList,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            ret = res.stdout.readlines()
            if ret:
                return ret
            else:
                return None
        except Exception, e:
            sys.exit("Process terminated unexpectedly:\n\t%s" % e)

    def createTicket(self, jiraSummary):
        """
        Create a JIRA issue of type task
        @input -- summary to use for jira issue
        @output -- JIRA issue id
        """
        cmdList = ["--action", "createIssue", 
                "--project", "CDE", 
                "--type", "task",
                "--labels", "HelpTicket",
                "--assignee", self.assignee,
                "--summary", jiraSummary] 
        res = self._runJIRACmd(cmdList)
        if not res: # something bad happened
            return None

        # isolate the jira issue id
        # XXX - jira cli returns different lists depending on whether
        # or not things are invoked with the --debug flag. ack. 
        id = ""
        if self.verbose:
            print "+++++++++++++++"
            print "Raw dump of ticket create:"
            print res
            print "+++++++++++++++"

            id = re.sub(r'created .*', "", res[-2])
            id = re.sub(r'Issue ', "", id)
        else:
            id = re.sub(r'created .*', "", res[-1])
            id = re.sub(r'Issue ', "", id)

        return id

    def closeTicket(self, id):
        """
        For a specified JIRA issue, progress it to "Closed"

        @input -- JIRA id
        @output -- return True for success, False otherwise
        """
        cmdList = ["--action", "progressIssue", 
                    "--resolution", "Done", 
                    "--issue", id,
                    "--step", "Close Issue"] 
        res = self._runJIRACmd(cmdList)

        if self.verbose:
            print "+++++++++++++++"
            print "Raw dump of ticket close:"
            print res
            print "+++++++++++++++"

        # this is horrible, but a quick hack to address weird results 
        # behavior from jira CLI
        if "Successfully progressed" in res[-1] or "Successfully progressed" in res[-2]:
            return True
        else:
            return False

    def addWorkDuration(self, id):
        """
        For a specified JIRA issue, log work as specified
        by the 'duration' user argument

        @input -- JIRA issue id
        @output -- True for success, False otherwise
        """
        cmdList = ["--action", "addWork", 
                    "--timeSpent", self.duration, 
                    "--issue", id]
        res = self._runJIRACmd(cmdList)

        if self.verbose:
            print "*************"
            print "For work duration, JIRA returned:"
            print "--------------------------------"
            print res
            print "*************"

            if "added for issue" in res[-2]:
                return True
        else:
            if "added for issue" in res[-1]:
                return True

        return False

    def LogTicketAndClose(self):
        """
        Given a username and a comment, create then immediately
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
                      help="name of user needing assistance.")
    parser.add_option("-c",
                      metavar="<comment>",
                      dest="comment",
                      help="brief description of the task, will be used as the "
                           "bug summary")
    parser.add_option("-d",
                      metavar="<duration>",
                      dest="duration",
                      help="amount of time spent, i.e.: 2h, 3d, 1w (optional)")
    parser.add_option("-v",
                      metavar="<verbose>",
                      dest="verbose",
              action = "store_true",
                      help="tell jira CLI to run verbosely")
    options, args = parser.parse_args()

    if not (options.user or options.comment):
        parser.error("ERROR: Missing required options.  Please run "
             "'pony -h' for usage")

    # keeps things clean for now, in the future we may want to expand the number
    # of tasks this script can do
    if args:
        parser.error("This program does not accept the following as "
                     "arguments: %s" % str(args))

    # instantiate class
    p = Pony(options.user, options.comment, options.duration, options.verbose)

    # log it
    p.LogTicketAndClose()

if __name__ == "__main__":
    main()

