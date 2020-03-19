# Author: Sivaprasad Padisetty
# Copyright 2013, Licensed under Apache License 2.0
#

function Test1 ()
{
    'Hello this is test1 from TestModule'
}


function Test2 ()
{
    'Hello this is test2'
    if (! (Test-Path c:\test)) {
        'returning 3010, should continue after reboot'
        $null = md c:\test
        exit 3010 # Reboot requested
    } else {
        del c:\test -force
        'Test2 completed!!!'
    }
}


