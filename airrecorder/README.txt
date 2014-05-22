AirRecorder
-----------

Connects to a controller via SSH/Telnet and submits a set of predefined 
commands at regular intervals or once.
The output is saved in a file named "air-recorder-<id>-<date>-<time>.log".

For help, run with: 
java -jar AirRecorder.jar
 
For recording, run with:
java -jar AirRecorder.jar <controllerip>


Arguments:
---------
N/A


Files:
-----
<controllerip> or <controllerip>.txt
commands or commands.txt
placeholders or placeholders.txt


Format:
------
* Put commands into a file named "commands" or "commands.txt"
	One command per line: <interval in seconds>,<CLI command>
	i.e.: 5,show user
	Placeholders are referenced with ${<placeholdername>}
	i.e.: 5,show ap active ${apname1}
	Pre-defined variables are referenced with %{pre-defined variable}
	i.e.: 5,show ap active %{ap:name}
	Variables are referenced with #{variable}
	i.e.: 5,show ap active #{show ap active,Active AP Table,Name}
	NOTE: an interval of zero will run the command only once.

* Put placeholders into a file named "placeholders" or "placeholders.txt"
	One placeholder per line: <placeholdername>=<value1>,<value2>
	i.e.: apname1=AP5
	i.e.: apname2=AP5,AP7

* If a file named after the controller IP address exists, it shall contain
	<username>, <password>, <enable password> each on a separate line

* Pre-defined variables
    Pre-defined variables are just well known shortcuts to regular variables:
    	%{ap:name} => #{show ap active,Active AP Table,Name}
		%{ap:group} => #{show ap active,Active AP Table,Group}
		%{ap-group:name} => #{show ap-group,AP group List,Name}
		%{user:ip} => #{show user-table,Users,IP}
		%{user:mac => #{show user-table,Users,MAC}
		%{user:name} => #{show user-table,Users,Name}
    
* Variables
    Variables have dynamic content. The definition of a variable is as:
        #{command,marker,column[,ttl]}
        
        command is the command to execute to fetch values, i.e. "show ap active"
        marker is the marker line to parse output, i.e. "Active AP Table"
        column is the name of the column to extract, i.e. "Name"
        ttl is the time-to-live of the variable:
        	-1: variable is loaded once
        	0: variable is loaded every time
        	x: variable is loaded every x seconds
    NOTE: the variable parser currently understands only the table based output
          commands
          marker and column are CASE sensitive
