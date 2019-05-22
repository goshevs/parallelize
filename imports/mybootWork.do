********************************************************************************
***   IMPORT: myboot WORK


*** REMOTE WORK FILE

args jobID

*** Execute URL if provided
capture do `s(pURL)'

if regexm("\`jobID'", "^([0-9]+).+") {
	local pid = "\`=regexs(1)'"
}

noi di "\`pid'"
set seed \`pid'
local mySeed = \`pid' + 10000000 * runiform()

noi di "\`mySeed'"
set seed \`mySeed'

use "`dataDir'/`fName'", clear

ssc install regsave

bsample, strata(foreign)

`command'

*** Save estimates
regsave
save ~/`remoteDir'/data/output/data/`dCommand'_data_\`pid', replace

*** Save metadata
clear
set obs 1
gen seed = \`mySeed'
gen jobID = \`pid'
save ~/`remoteDir'/data/output/metadata/`dCommand'_metadata_\`pid', replace

