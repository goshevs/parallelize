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

args request remoteScripts nrep jobname jobID callBack email nodes ppn pmem walltime


********************************************************************************
*** Define functions
********************************************************************************

************************
*** MASTER submission program 

capture program drop _submitMaster
program define _submitMaster
	
	args remoteScripts nrep jobname callBack email nodes ppn pmem walltime
	
	*** Compose the master submit 
	local masterHeader  "cd `remoteScripts'/logs`=char(10)'qsub << \EOF1`=char(10)'#PBS -N masterJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local masterResources  "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=12:00:00`=char(10)'"
	local spoolerHeader "cd `remoteScripts'/logs`=char(10)'qsub << \EOF2`=char(10)'#PBS -N spoolerJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local spoolerResources "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=120:00:00`=char(10)'"
	local spoolerWork "cd `remoteScripts'/logs`=char(10)'module load stata/15`=char(10)'stata-mp -b `remoteScripts'/scripts/_runBundle.do spool `remoteScripts' `nrep' `jobname' 0 `callBack' `email' `nodes' `ppn' `pmem' `walltime'`=char(10)'"
	local spoolerTail "EOF2`=char(10)'"
	local monitorHeader "cd `remoteScripts'/logs`=char(10)'qsub << \EOF3`=char(10)'#PBS -N monitorJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local monitorResources "#PBS -l nodes=1:ppn=1,pmem=1gb,walltime=120:00:00`=char(10)'"
	local monitorEmail "#PBS -m e`=char(10)'#PBS -M `email'`=char(10)'"
	local monitorWork "cd `remoteScripts'/logs`=char(10)'module load stata/15`=char(10)'module load moab`=char(10)'stata-mp -b `remoteScripts'/scripts/_runBundle.do monitor `remoteScripts' `nrep' `jobname' 0 `callBack' `email' `nodes' `ppn' `pmem' `walltime'`=char(10)'"
	local monitorTail "EOF3`=char(10)'"
	local masterTail "EOF1`=char(10)'"

	*** Combine all parts 
	if "`email'" == "0" {
		local masterFileContent "`masterHeader'`masterResources'`spoolerHeader'`spoolerResources'`spoolerWork'`spoolerTail'`monitorHeader'`monitorResources'`monitorWork'`monitorTail'`masterTail'"
	}
	else {
		local masterFileContent "`masterHeader'`masterResources'`spoolerHeader'`spoolerResources'`spoolerWork'`spoolerTail'`monitorHeader'`monitorResources'`monitorEmail'`monitorWork'`monitorTail'`masterTail'"
	}
	
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

	args remoteScripts jobname nodes ppn pmem walltime
	
	*** Compose the submit file
	local pbsHeader "cd `remoteScripts'/logs`=char(10)'qsub << \EOF`=char(10)'#PBS -N `jobname'`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local pbsResources "#PBS -l nodes=`nodes':ppn=`ppn',pmem=`pmem',walltime=`walltime'`=char(10)'"
	local pbsCommands "module load stata/15`=char(10)'cd `remoteScripts'/logs`=char(10)'"
	local pbsDofile "stata-mp -b `remoteScripts'/scripts/_runBundle.do work `remoteScripts' 0 na $"  // this is written like this so that Stata can write it properly!
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



************************
*** WORK COLLECTION program

capture program drop _collectWork
program define _collectWork, sclass

	args remoteScripts jobname
	
	*** Compose the submit file
	local pbsHeader "cd `remoteScripts'/logs`=char(10)'qsub << \EOF`=char(10)'#PBS -N collectJob`=char(10)'#PBS -S /bin/bash`=char(10)'"
	local pbsResources "#PBS -l nodes=1:ppn=4,pmem=10gb,walltime=120:00:00`=char(10)'"
	local pbsCommands "module load stata/15`=char(10)'cd `remoteScripts'/logs`=char(10)'"
	local pbsDofile "stata-mp -b `remoteScripts'/scripts/_runBundle.do collect `remoteScripts' 0 `jobname'"  
	local pbsEnd "`=char(10)'EOF`=char(10)'"
	
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





**** Process checker program
capture program drop _waitAndCheck
program define _waitAndCheck

	args sleepTime jobname
	
	sleep `sleepTime'
	ashell showq -n | grep `jobname' | wc -l   // install ashell
	
	while `r(o1)' ~= 0 {
		sleep `sleepTime'
		ashell showq -n | grep `jobname' | wc -l
	}
	
end


*** Callback input converter
capture program drop _cbTranslate
program define _cbTranslate, sclass

	args callback
	
	if regexm("`callback'", "([0-9]+)([smhd])") {
		local duration "`=regexs(1)'"
		local unit "`=regexs(2)'"
		
		if "`unit'" == "s" {
			local len = `duration' * 1000
		}
		else if "`unit'" == "m" {
			local len = `duration' * 60000
		}
		else if "`unit'" == "h" {
			local len = `duration' * 3600000
		}
		else if "`unit'" == "d" {
			local len = `duration' * 86400000
		}
	}
	else {
		noi di in r "Incorrectly specified callback option"
		exit 489
	}
	
	sreturn local lenSleep "`len'"
	
end





********************************************************************************
*** Program code
********************************************************************************

if "`request'" == "master" {
	_submitMaster "`remoteScripts'" "`nrep'" "`jobname'" "`callBack'" "`email'" "`nodes'" "`ppn'" "`pmem'" "`walltime'"
	
}	
else if "`request'" == "spool" {
	forval i=1/`nrep' { 
		_submitWork "`remoteScripts'" "`c(username)'_`jobname'" "`nodes'" "`ppn'" "`pmem'" "`walltime'"
	}
}
else if "`request'" == "work" {
	do "`remoteScripts'/scripts/_workJob.do" "`jobID'"
}
else if "`request'" == "monitor" {

	*** Parse callBack //sleep 600000 = 10 minutes
	_cbTranslate "`callBack'"
	local callBackTR "`s(lenSleep)'"
	
	_waitAndCheck "`callBackTR'" "spoolerJob" // wait for spooler job to complete
	_waitAndCheck "`callBackTR'" "`c(username)'_`jobname'"   // wait for work jobs to complete
	
	*** Count how many output files we have
	ashell ls `remoteScripts'/data/output | wc -l
	local lostJobs = `nrep' - `r(o1)'   // calculate missing jobs
	
	*** If there are lost jobs, run more
	while `lostJobs' > 0 {
		forval i=1/`lostJobs' { 
			_submitWork "`remoteScripts'" "`c(username)'_`jobname'" "`nodes'" "`ppn'" "`pmem'" "`walltime'"
		}
		_waitAndCheck "`callBackTR'" "`c(username)'_`jobname'"
		
		ashell ls `remoteScripts'/data/output | wc -l
		local lostJobs = `nrep' - `r(o1)'
	}
	
	*** Collect data
	_collectWork "`remoteScripts'" "`jobname'"
	
}
else if "`request'" == "collect" {
	
	local outputFiles: dir "`remoteScripts'/data/output" files "*.dta"
	local count = 1
	foreach outFile of local outputFiles {
		if `count' == 1 {
			use "`remoteScripts'/data/output/`outFile'", clear
		}
		else {
			append using "`remoteScripts'/data/output/`outFile'"
		}
		local ++count
	}
	save "`remoteScripts'/data/final/parallelize_`jobname'", replace
	
}
else {
	noi di in r "Invalid request"
	exit 489
}

exit






