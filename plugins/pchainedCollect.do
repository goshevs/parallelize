********************************************************************************
***   PLUGIN: -pchained- COLLECT


*** REMOTE COLLECTION FILE  ***

local outputDFiles: dir "`remoteDir'/data/output/data" files "pchained_data*.dta"
local outputMDFiles: dir "`remoteDir'/data/output/metadata" files "pchained_metadata*.dta"

local uid = subinstr("`uid'", "##", " ",.)
noi di "UID: `uid'"

*** Collect imputed datasets
local count = 1
foreach outFile of local outputDFiles {
	if `count' == 1 {
		use "`remoteDir'/data/output/data/`outFile'", clear
	}
	else {
		mi add `uid' using "`remoteDir'/data/output/data/`outFile'"
	}
	local ++count
}
save "`remoteDir'/data/final/data/pchained_parall_`jobname'", replace

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
save "`remoteDir'/data/final/metadata/pchained_parall_md_`jobname'", replace

