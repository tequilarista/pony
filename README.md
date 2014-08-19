Overview
========

"You can't have a pony (except you can)"

A tool for fast logging of JIRA tasks to track support interrupts

Requirements
=============
Needs to have access to the JIRA cli tool.  It should be able to find it relative to 
the repo's installed location, but if not, easiest alternative is to create
a conf file:

    ~/.pony.conf

and add the following line:

    JIRA_CMD = "/path/to/jira.sh"

You can also set JIRA_CMD as an environment variable.

Has been tested on OSX and Linux.  Has been tested with jira-cli-3.6.0. 

Known Issues
============
* There's a problem parsing the cli output with Jira 6.2.5.  The ticket is created but 
pony thinks there was an error. 

* Not super well-tested at the moment

Authors
-------
Author:: Tara Hernandez (tequilarista@gmail.com)

