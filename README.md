Overview
========

"You can't have a pony (except you can)"

A tool for fast logging of JIRA tasks.

Requirements
=============
Need to have JIRA python module installed.  Easiest way is via pip, assuming you have it already:

    % sudo pip install jira

Usage
=====
    Usage: pony [options]
    
    Options:
      -h, --help       show this help message and exit
      -u <customer>    name of user needing assistance -- REQUIRED.
      -c <comment>     brief description of the task, will be used as the bug
                       summary -- REQUIRED.
      -d <duration>    amount of time spent, i.e.: 2h, 3d, 1w -- OPTIONAL
      -a <serverAuth>  Name of person logging ticket, to use as credentials to bug
                       system -- REQUIRED (but can be set in template)
      -p <password>    Password to go with -e option -- REQUIRED (but can be set
                       in template.
      -s <serverURL>   HTTP URL to bug system -- REQUIRED (but can be set in
                       template.
      -x <project>     JIRA project code
      -t               Run 'pony -t' to create ~/.pony.conf template file to store
                       server info

Summary:
-------
To create easy access template, run:

    % pony -t

Edit subsequent ~/.pony.conf file -- fill in the blanks as appropriate to 
avoid having to specify the -a, -p, -s and -x options all the time...

Then you can do:

    % pony -u my.customer -c "needed help with this stuff"


Note: it's currently assumed that the values of the USER environment variable is the assignee 
of a pony task, and if that var doesn't exist, defaults to serverAuth parameter.  This is so you
can use a unique account to log all pony bugs, but is easy to change in the class constructor if
you want to change that behavior.


Authors
-------
Author:: Tara Hernandez (tequilarista@gmail.com)

