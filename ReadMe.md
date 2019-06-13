#PolicyLog-Errors

This script will reach into your database and extract all policies that have a failed log and export the information to a .txt file. 

Exported data includes:
1. Computer Name
1. Policy ID
1. Policy Name
1. Policy Execution Time
1. Log Details

There's a number of variables that can be hardcoded at the top of the script, including updating the save-to location for the output file.

##Process to run script
1. Copy to databse server
1. Run script with "bash /path/to/PolicyLog-Errors.sh"
1. Fill in data as prompted.
