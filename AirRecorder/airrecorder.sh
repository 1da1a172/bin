#!/usr/bin/sh
java -jar airrecorder.jar -i -m --post-command-delay 200 --max-log-size 10 --no-local-timing --reporting-interval 5 $@
