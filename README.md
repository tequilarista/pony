Overview
========

"You can't have a pony (except you can)"

A tool for fast logging of JIRA tasks to track support interrupts.  Opens and closes tickets in a 
single action, adds a "HelpTicket" label for ease of querying.

Usage: pony [options]

Options:
  -h, --help     show this help message and exit
  -u <user>      name of user needing assistance.
  -c <comment>   brief description of the task, will be used as the bug
                 summary
  -d <duration>  amount of time spent, i.e.: 2h, 3d, 1w (optional)
  -v             tell jira CLI to run verbosely

% pony -u joe.developer -c "debugged weird config problem breaking local build" -d 4h
HelpTicket ABC-1234 succesfully logged!

Requirements
=============
Needs to have access to the JIRA cli tool.  It should be able to find it relative to 
the repo's installed location, but if not, easiest alternative is to create
a conf file:

    ~/.pony.conf

and add the following line:

    JIRA_CMD = "/path/to/jira.sh"

You can also set JIRA_CMD as an environment variable.  The jira.sh should be updated to use
shared JIRA credentials that all pony tickets are logged as.  A future feature would be to pass 
login information as a parameter.


Tested on OSX (Mavericks) and Linux (Centos).  
Known to work on JIRA 6.2.5
Known to work with jira-cli-3.6.0. Will be evaluating upgrades in the not-too-distant future.

Known Issues
============
* Susceptible to changes in JIRA versions -- the order of return values seem to move around.
* Not super well-tested at the moment.  Let me know what you find.

Authors
-------
Author:: Tara Hernandez (tequilarista@gmail.com)

