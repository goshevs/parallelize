********************************************************************************
***   PLUGIN: -mytest- COLLECT


*** REMOTE COLLECTION FILE  ***

local outputFiles: dir "`remoteScripts'/data/output/data" files "*.dta"
local count = 1

foreach outFile of local outputFiles {
	if `count' == 1 {
		use "`remoteScripts'/data/output/data/`outFile'", clear
	}
	else {
		append using "`remoteScripts'/data/output/data/`outFile'"
	}
	local ++count
}
save "`remoteScripts'/data/final/data/parallelize_`jobname'", replace
