AirRecorder
-----------

- Connects to an Aruba controller, Instant VC or MSR via SSH/Telnet and submits
  a set of predefined commands at regular intervals or once.
  The output is saved in a file named 
    "air-recorder-<controller>-<date>-<time>-<id>.log".

- Records AMON messages into CSV files and optionally processes them.
  The output is saved in a file named 
    "air-recorder-<date>-<time>-<#>-<amon-message-name>-<id>.csv".

For help, run with: 
java -jar AirRecorder.jar
java -jar AirRecorder.jar -h
 
Please read the HOWTO.txt file for instructions.
