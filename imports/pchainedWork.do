********************************************************************************
***   IMPORT: -pchained- WORK

*** Inherited macros: all macros passed to parallelize including 
** --> `s(pURL)'
** --> `dataDir'
** --> `fName'
** --> `command'
** --> `dCommand'
** --> `remoteDir'


*** REMOTE WORK FILE  *** FIX RANDOM SEED GENERATOR!!!

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

set prefix parallelize

`command'

*** Save data
save ~/`remoteDir'/data/output/data/`dCommand'_data_\`pid', replace

*** Save metadata
clear
set obs 1
gen seed = \`mySeed'
gen jobID = \`pid'
save ~/`remoteDir'/data/output/metadata/`dCommand'_metadata_\`pid', replace




