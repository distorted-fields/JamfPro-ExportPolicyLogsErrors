#!/bin/bash
#
#
#     Created by A.Hodgson
#      Date: 06/12/2019
#      Purpose: Export Failed Policy logs from the database
#  
#
######################################

#hardcode variable prompts if desired
#operating system - 1 for Linux, 2 for macOS
OS=""
#database user
user=""
#database user password
password=""
#database name
db=""

#output file options - update if you desire a new location
linuxOutput=/tmp/PolicyLogs-Errors.txt
macOSoutput=/Users/Shared/PolicyLogs-Errors.txt


##############################################################
#
# DO NOT EDIT BELOW THIS LINE
#
##############################################################


#set variables for mySQL - check if hardcoded, prompt if not
#os
if [ -z $OS ]
then
	read -p "Please identify server operating system. 1 for Linux, 2 for macOS: " OS
fi

#user
if [ -z $user ]
then
	read -p "Please enter your MySQL username: " user
fi

#user password hidden from terminal
if [ -z $password ]
then
	prompt="Please enter your MySQL password: "
	while IFS= read -p "$prompt" -r -s -n 1 char 
	do
	if [[ $char == $'\0' ]];     then
	    break
	fi
	if [[ $char == $'\177' ]];  then
	    prompt=$'\b \b'
	    password="${password%?}"
	else
	    prompt='*'
	    password+="$char"
	fi
	done
fi
#export mysql password to clear warning
export MYSQL_PWD="$password"
echo ""

#database name
if [ -z $db ]
then
	read -p "Please enter your Jamf database name: " db
fi

#set mysql and output variables dependant on OS
if [ $OS == "1" ]
then
	#output file
	output=$linuxOutput
	#remove output if found
	if [ -f $output ]
	then
		rm $output
	fi
	#mysql location
	read -p "Please enter the location of the MySql binary (leave blank for default path - /usr/bin/mysql): " mySQL
	if [ -z "$mySQL" ]
	then
		mySQL="/usr/bin/mysql"
	fi
elif [ $OS == "2" ]	
then
	#output file
	output=$macOSoutput
	#remove output if found
	if [ -f $output ]
	then
		rm $output
	fi
	#mysql location
	read -p "Please enter the location of the MySql binary (leave blank for default path - /usr/local/mysql/bin/mysql): " mySQL
	if [ -z "$mySQL" ]
	then 
		mySQL="/usr/local/mysql/bin/mysql"
	fi
fi

#check for MySQL location, gracefully quit if not found in location
if [ -e $mySQL ]
then
	echo "MySQL found, running commands..."
else
	echo "MySQL not found, exiting."
	exit 0
fi

##############################################################

#grab computer and log ids where there was failures
function getLogs()
{

	i=0
	#build an array of computer ids where there are error logs
	while IFS=$'\t' read raw_computer_ids[i++];do
	    :;done  < <($mySQL -u$user $db -se  "select computer_id from logs where error=1;")

	#remove dupes from ID array
	computer_ids=($(echo "${raw_computer_ids[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

	#get the length of the array and a variable for traversing
	totalComps="${#computer_ids[@]}"
	#((totalComps--)) #have to subtract 1 due to the while loop above including an empty space
	comp_count=0

	echo "Computers with Policy failures: $totalComps" >> $output
	echo "" >> $output

	#traverse the array and output the mysql commands to a txt file
	while [ $comp_count -lt $totalComps ]
	do
		#command to get the computer name for readability in the output file
		mysqlcommand="select computer_name from computers where computer_id='${computer_ids[$comp_count]}';"		
		computerName=$($mySQL -u$user $db -se "$mysqlcommand")
		
		i=$((comp_count + 1))
		echo "Computer $i: $computerName - the following policies have errors:" >> $output

		#command to get errored policy logs based on computer id
		#select log_id from logs where computer_id=XXXX and error=1;
		i=0
		#build an array of computer ids where there are error logs
		while IFS=$'\t' read raw_log_ids[i++];do
	    :;done  < <($mySQL -u$user $db -se  "select log_id from logs where computer_id='${computer_ids[$comp_count]}' and error=1;")
	    #remove dupes from ID array
		log_ids=($(echo "${raw_log_ids[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
		
		#get the length of the array and a variable for traversing
		totalLogs="${#log_ids[@]}"
		log_count=0

		#traverse the array and output the mysql commands to a txt file
		while [ $log_count -lt $totalLogs ]
		do
			#command to get policy_id needed to find policy name
			#select policy_id from policy_history where log_id=XXXX;
			mysqlcommand="select policy_id from policy_history where log_id='${log_ids[$log_count]}';"		
			policyID=$($mySQL -u$user $db -se "$mysqlcommand")
			
			#command to get policy name
			#select name from policies where policy_id=XXXX;
			mysqlcommand="select name from policies where policy_id='$policyID';"		
			policyName=$($mySQL -u$user $db -se "$mysqlcommand")

			#command to get policy date
			#select date_entered_epoch from logs where log_id=XXXX and computer_id=XXXX;
			mysqlcommand="select date_entered_epoch from logs where log_id='${log_ids[$log_count]}' and computer_id='${computer_ids[$comp_count]}';"		
			raw_policyDate=$($mySQL -u$user $db -se "$mysqlcommand")
			#convert date - depending on OS
			if [ $OS == "1" ]
			then
				policyDate=$(date -d @$(($raw_policyDate/1000)))
			elif [ $OS == "2" ]	
			then
				policyDate=$(date -r $(($raw_policyDate/1000)))
			fi

			#command to get policy details 
			#select action from log_actions where log_id=XXXX;
			mysqlcommand="select action from log_actions where log_id='${log_ids[$log_count]}';"		
			policyDetails=$($mySQL -u$user $db -se "$mysqlcommand")

			echo "Policy ID: $policyID" >> $output
			echo "Policy Name: $policyName" >> $output
			echo "Execution Date: $policyDate" >> $output
			echo "Details:" >> $output 
			echo -e "$policyDetails" >> $output
			echo "" >> $output
			((log_count++))
		done

		echo "" >> $output
		echo "" >> $output
		((comp_count++))
	done
}


##############################################################
#call main function and delcare and exit
currentTime=$(date)
echo "Report Run on: $currentTime" >> $output
getLogs
echo ""
echo "All outputs have been written to $output"
exit 0
