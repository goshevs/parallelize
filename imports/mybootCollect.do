********************************************************************************
***   IMPORT: myboot COLLECT


*** REMOTE COLLECTION FILE  ***

local outputDFiles: dir "`remoteDir'/data/output/data" files "regress_data*.dta"
local outputMDFiles: dir "`remoteDir'/data/output/metadata" files "regress_metadata*.dta"


local count = 1
foreach outFile of local outputDFiles {
	if `count' == 1 {
		use "`remoteDir'/data/output/data/`outFile'", clear
	}
	else {
		append using "`remoteDir'/data/output/data/`outFile'"
	}
	local ++count
}
save "`remoteDir'/data/final/data/myboot_`jobname'", replace

*** Collect metadata for imputed datasets
local count = 1
foreach outFile of local outputMDFiles {
	if `count' == 1 {
		use "`remoteDir'/data/output/metadata/`outFile'", clear
	}
	else {
		append using "`remoteDir'/data/output/metadata/`outFile'"
	}
	local ++count
}
save "`remoteDir'/data/final/metadata/myboot_`jobname'", replace
