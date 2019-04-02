********************************************************************************
***  Master run bundle 
***
***
**
**
**
**
**
**
**

args request remoteScripts nrep jobID

set trace on
********************************************************************************
*** Define functions
********************************************************************************


************************
*** MASTER submission program 

capture program drop _submitMaster
program define _submitMaster
	
	args remoteScripts nrep
	
	*** Compose the master submit 
	local masterHeader  "qsub << \EOF1`=char(10)'#PBS -N masterJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local masterResources  "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=12:00:00`=char(10)'"
	local spoolerHeader "qsub << \EOF2`=char(10)'#PBS -N spoolerJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local spoolerResources "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=120:00:00`=char(10)'"
	local spoolerWork "module load stata/15`=char(10)'stata-mp -b `remoteScripts'/_runBundle.do spool `remoteScripts' `nrep'`=char(10)'"
	local spoolerTail "EOF2`=char(10)'"
	/*
*	local monitorHeader "qsub << \EOF3`=char(10)'#PBS -N monitorJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
*	local monitorResources "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=120:00:00`=char(10)'"
*	local monitorWork "module load stata/15`=char(10)'`=char(10)'stata-mp -b `remoteScripts'/_runBundle.do monitor `remoteScripts'"`=char(10)'"
*	local monitorTail "EOF3`=char(10)'"
	*/
	local masterTail "EOF1`=char(10)'"

	*** Combine all parts
	local masterFileContent "`masterHeader'`masterResources'`spoolerHeader'`spoolerResources'`spoolerWork'`spoolerTail'`monitorHeader'`monitorResources'`monitorWork'`monitorTail'`masterTail'"

	*** Initialize a filename and a temp file
	tempfile mSubmit
	tempname mfName

	*** Write out the content to the file
	file open `mfName' using `mSubmit', write text replace
	file write `mfName' `"`masterFileContent'"'
	file close `mfName'

	*** Submit the job
	shell cat `mSubmit' | bash -s

end


************************
*** WORK submission program

capture program drop _submitWork
program define _submitWork, sclass

	args remoteScripts jobName
	
	*** Compose the submit file
	local pbsHeader "cd `remoteScripts'`=char(10)'qsub << \EOF`=char(10)'#PBS -N `jobName'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local pbsResources "#PBS -l nodes=1:ppn=1,pmem=2gb,walltime=05:00:00`=char(10)'"
	local pbsCommands "module load stata/15`=char(10)'"
	local pbsDofile "stata-mp -b `remoteScripts'/_runBundle.do work `remoteScripts' 0 $"  // this is written like this so that Stata can write it properly!
	local pbsEnd "PBS_JOBID`=char(10)'EOF`=char(10)'"
	
	*** Combine all parts
	local pbsFileContent `"`pbsTitle'`pbsHeader'`pbsResources'`pbsCommands'`pbsDofile'"'

	*** Initialize a filename and a temp file
	tempfile pbsSubmit
	tempname myfile
	
	*** Write out the content to the file
	file open `myfile' using `pbsSubmit', write text replace
	file write `myfile' `"`pbsFileContent'"'
	file write `myfile' `"`pbsEnd'"'
	file close `myfile'

	*** Submit to sirius
	shell cat `pbsSubmit' | bash -s
end


********************************************************************************
*** Program code
********************************************************************************

if "`request'" == "master" {
	_submitMaster "`remoteScripts'" "`nrep'"
}	
else if "`request'" == "spool" {
	forval i=1/`nrep' { 
		_submitWork "`remoteScripts'" "`c(username)'_parallel"
	}
}
else if "`request'" == "relaunch" {
	foreach i of global myLostJobs {
		mySubmit "`remoteLogOutput'" "`remoteScripts'" "`myWork'" "`i'" "`miles'" "`runType'"
	}
}
else if "`request'" == "work" {
	do "`remoteScripts'/_workJob.do `jobID'"
}
else if "`request'" == "monitor" {
	sleep 600000 // 10 minutes
	ashell showq -n | grep `c(username)' | grep `jobName' | wc -l // need to install ashell
	while `r(o1)' ~= 0 {
		sleep 600000
		ashell showq -n | grep `c(username)' | grep `jobName' | wc -l
	}

	**** Run the script to identify missing jobs
	do "`remoteScripts'/`myMissJobs'" "`startTeacher'" "`totalTeachers'"
	*** If there are lost jobs:
	while "{$myLostJobs}" ~= "" {
		do "`remoteScripts'/`mySpoolJob'" rerun "`startTeacher'" "`totalTeachers'" "`miles'" "`jobName'"
		
		sleep 600000 // 10 minutes
		ashell showq -n | grep `c(username)' | grep `jobName' | wc -l
		while `r(o1)' ~= 0 {
			sleep 600000
			ashell showq -n | grep `c(username)' | grep `jobName' | wc -l
		}
		do "`remoteScripts'/`myMissJobs'" "`startTeacher'" "`totalTeachers'"
	}
}
else {
	noi di in r "Invalid request"
	exit 489
}







