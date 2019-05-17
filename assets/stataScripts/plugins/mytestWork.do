********************************************************************************
***   PLUGIN: -mytest- WORK


*** REMOTE WORK FILE


file open `workHandle' using `workJob', write
file write `workHandle' "* This is the work file`=char(10)'"
file write `workHandle' "args jobID`=char(10)'"
if "`s(pURL)'" ~= "" {
	file write `workHandle' "do `s(pURL)'`=char(10)'"
}
file write `workHandle' `"if regexm("\`jobID'", "^([0-9]+).+") {`=char(10)'local pid = "\`=regexs(1)'"`=char(10)'noi di "\`pid'"`=char(10)'set seed \`pid'`=char(10)'local mySeed = \`pid' + 10000000 * runiform()`=char(10)'}`=char(10)'"'
file write `workHandle' `"set prefix parallelize`=char(10)'set seed \`mySeed'`=char(10)'noi di "\`mySeed'"`=char(10)'use `dataLoc'`=char(10)'"'
file write `workHandle' "`command'`=char(10)'"
file write `workHandle' "clear`=char(10)'set obs 1`=char(10)'gen mynum = \`r(mean)'`=char(10)'gen seed = \`mySeed'`=char(10)'gen jobID = \`pid'`=char(10)'save ~/`remoteDir'/data/output/data/data_\`=regexs(1)', replace"
file close `workHandle'
