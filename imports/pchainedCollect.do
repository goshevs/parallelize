********************************************************************************
***   IMPORT: -pchained- COLLECT


*** Inherited macros: all macros passed to parallelize including 
** --> `remoteDir'
** --> `argPass'
** --> `jobname'



*** REMOTE COLLECTION FILE  ***

local outputDFiles: dir "`remoteDir'/data/output/data" files "pchained_data*.dta"
local outputMDFiles: dir "`remoteDir'/data/output/metadata" files "pchained_metadata*.dta"

local argPass = subinstr("`argPass'", "##", " ",.)
noi di "UID: `argPass'"

*** Collect imputed datasets
local count = 1
foreach outFile of local outputDFiles {
	if `count' == 1 {
		use "`remoteDir'/data/output/data/`outFile'", clear
	}
	else {
		mi add `argPass' using "`remoteDir'/data/output/data/`outFile'"
	}
	local ++count
}
save "`remoteDir'/data/final/data/pchained_`jobname'", replace

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
save "`remoteDir'/data/final/metadata/pchained_`jobname'", replace

