********************************************************************************
***   IMPORT: generic monitoring functionality



*** Parse callBack //sleep 600000 = 10 minutes
_cbTranslate "`callBack'"
local callBackTR "`s(lenSleep)'"


_waitAndCheck "`callBackTR'" "spo_`jobname'" // wait for spooler job to complete
_waitAndCheck "`callBackTR'" "wor_`jobname'"   // wait for work jobs to complete


*** Count how many output files we have
ashell ls `remoteDir'/data/output/data | wc -l
local lostJobs = `nrep' - `r(o1)'   // calculate missing jobs

*** If there are lost jobs, run more
while `lostJobs' > 0 {
	forval i=1/`lostJobs' { 
		_submitWork "`remoteDir'" "`jobname'" "`nodes'" "`ppn'" "`pmem'" "`walltime'" "`wFName'"
	}
	_waitAndCheck "`callBackTR'" "wor_`jobname'"
	
	ashell ls `remoteDir'/data/output/data | wc -l
	local lostJobs = `nrep' - `r(o1)'
}

*** Collect data
_collectWork "`remoteDir'" "`jobname'" "`cFName'" "`argPass'"

