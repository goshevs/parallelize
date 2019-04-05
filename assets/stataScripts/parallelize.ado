********************************************************************************
*** Parallelize 
********************************************************************************
**
**
** Simo Goshev, Jason Bowman
**
** v. 0.01
**
**

***This is a prefix program (just like bootstrap, mi, xi, etc)
capture program drop parallelize
program define parallelize, eclass

	set prefix parallelize
	
	sreturn clear
	
	_on_colon_parse `0'
	
	local command `"`s(after)'"'
	local 0 `"`s(before)'"'
	
	syntax, CONspecs(string asis) [JOBspecs(string asis) DATAspecs(string asis) EXECspecs(string asis)  *]

	*** Parse connection specs
	_parseSpecs `"`conspecs'"'

	*** Collect all parameters
	if "`s(sshHost)'" == "" {  // if no .ssh configuration for the connection
	
		*** Parse the config file
		noi _parseConfig
		
		*** <><><> Collect and check user input
		foreach arg in username host port {
			if "`s(`arg')'" ~= "" {
				local `arg' "`s(`arg')'"
			}
			else {
				noi di _n in r "Please, provide argument `arg' in connection specs"
				exit 489
			}
		}
		local host "`username'@`host'"
	}
	else {
		local host "`s(sshHost)'"
	}
	
	*** Parse job specs
	_parseSpecs `"`jobspecs'"'

	*** <><><> Collect and check user input
	foreach arg in nodes ppn pmem walltime jobname {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in job specs"
			exit 489
		}
	}
	
	*** Parse DATA specs
	_parseSpecs `"`dataspecs'"'
	
	*** <><><> Collect and check user input
	foreach arg in file loc {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in data specs"
			exit 489
		}
	}
		
	*** Parse EXEC specs
	_parseSpecs `"`execspecs'"'
	
	*** <><><> Collect and check user input
	foreach arg in nrep cbfreq email {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in execution specs"
			exit 489
		}
	}
	
	
	*** Compose and transfer content to remote machine
	tempname remoteDir    // directory on remote machine
	noi _setupAndSubmit "`host'" "`remoteDir'" `"`file'"' `"`loc'"' `"`s(pURL)'"' `"`command'"' "`nrep'" "`jobname'" "`cbfreq'" "`email'" "`nodes'" "`ppn'" "`pmem'" "`walltime'"
	
	*** We can feed c(prefix) to -pchained-, -ifeats-, etc. (see conditionals in mytest)
	
	*** Here we need machinery to farm out the work and collect results; we need
	*** a message exchange interface for the user; need api functionality for 
	*** pulling and pushing data
	
	*** Execute the command
	* `command'

end


*** Function which parses all specs
capture program drop _parseSpecs
program define _parseSpecs, sclass

	args specs

	local rightHS "([a-zA-Z0-9\\\/:~,\._ ]*)"
	local strregex "([a-zA-Z]+)[ ]*=[ ]*(\'|\"|[ ]*)`rightHS'(\'|\"|[ ]*)"

	while regexm(`"`specs'"', `"`strregex'"') {
		local arg   `=regexs(0)'
		local myKey `=regexs(1)'
		local myVal `=regexs(3)'
		local specs = trim(subinstr(`"`specs'"', `"`arg'"', "", .))
		
		** Post to sreturn
		sreturn local `myKey' `"`myVal'"'
	}
end

*** Parse the config file
capture program drop _parseConfig
program define _parseConfig, sclass
	
	tempname myConf 
	file open `myConf' using "`s(configFile)'", r
	
	file read `myConf' line
	while r(eof) == 0 { 
		if regexm("`macval(line)'", "\[`s(profile)'\]") {
			file read `myConf' line
			_parseSpecs `"`macval(line)'"'
			while `"`macval(line)'"' ~= "" {
				_parseSpecs `"`macval(line)'"'
				file read `myConf' line
			}
		}
		file read `myConf' line
	}
end
	
*** Writing files and sending them to the remote machine
capture program drop _setupAndSubmit
program define _setupAndSubmit, sclass

	args host remoteDir dfile dloc url command nrep jobname callback email nodes ppn pmem walltime
	
	
	noi di " `host' `remoteDir' `dfile' `dloc' `url' `command' `nrep' `jobname' `callback' `email' `nodes' `ppn' `pmem' `walltime'"
	*** LOCATION OF DATA
	if "`dloc'" == "local" {
		if regexm("`dfile'", "^(.+/)*(.+)$") {
			local fName `=regexs(2)'
		}
		local dataLoc "~/`remoteDir'/data/initial/`fName'"
	}
	else if "`dloc'" == "cluster" {
		local dataLoc "`dfile'"
	}
	else {
		*** box ***
	}
	
	*** REMOTE WORK FILE  *** FIX RANDOM SEED GENERATOR!!!
	tempfile workJob 
	tempname workHandle
	
	file open `workHandle' using `workJob', write
	file write `workHandle' "* This is the work file`=char(10)'"
	file write `workHandle' "args jobID`=char(10)'"
	if "`s(pURL)'" ~= "" {
		file write `workHandle' "do `s(pURL)'`=char(10)'"
	}
	file write `workHandle' `"if regexm("\`jobID'", "^([0-9]+).+") {`=char(10)'local pid = "\`=regexs(1)'"`=char(10)'noi di "\`pid'"`=char(10)'set seed \`pid'`=char(10)'local mySeed = \`pid' + 10000000 * runiform()`=char(10)'}`=char(10)'"'
	file write `workHandle' `"set prefix parallelize`=char(10)'set seed \`mySeed'`=char(10)'noi di "\`mySeed'"`=char(10)'use `dataLoc'`=char(10)'"'
	file write `workHandle' "`command'`=char(10)'"
	file write `workHandle' "clear`=char(10)'set obs 1`=char(10)'gen mynum = \`r(mean)'`=char(10)'gen seed = \`mySeed'`=char(10)'save ~/`remoteDir'/data/output/data_\`=regexs(1)', replace"
	file close `workHandle'
	
	
	*** REMOTE SETUP SCRIPT
	
	tempfile remoteDirs
	tempname dirsHandle
	
	*** Compose and write out REMOTE SETUP SCRIPT
	file open `dirsHandle' using `remoteDirs', write
	file write `dirsHandle' "mkdir -p `remoteDir'/scripts `remoteDir'/data  `remoteDir'/logs && "
	file write `dirsHandle' "mkdir -p `remoteDir'/data/initial `remoteDir'/data/output && "
*	file write `dirsHandle' "wget -q https://raw.githubusercontent.com/goshevs/parallelize/devel/assets/stataScripts/_runBundle.do -P ./`remoteDir'/scripts/; "
	file write `dirsHandle' "echo 'Done!'"
	file close `dirsHandle'
	
	
	*** REMOTE SUBMISSION SCRIPT
	
	tempfile remoteSubmit
	tempname submitHandle
	
	*** Compose and write out REMOTE SUBMIT SCRIPT
	file open `submitHandle' using `remoteSubmit', write
	file write `submitHandle' "cd `remoteDir'/logs && "
	file write `submitHandle' "`find /usr/public/stata -name stata-mp 2>/dev/null` -b ../scripts/_runBundle.do master ~/`remoteDir' `nrep' `jobname' 0 `callback' `email' `nodes' `ppn' `pmem' `walltime' && "
	file write `submitHandle' "echo 'Done!'"
	file close `submitHandle'


	*shell powershell.exe -noexit -command "Get-Content `pHolder'"
	*shell powershell.exe -noexit -command "ssh `host'"
	
	
	**** CALL THE SHELL AND EXECUTE ALL OPERATIONS
	
	*** Not tested on macOS and Linux
	if "`c(os)'" == "Windows" {
		local osCat "Get-Content -Raw"
		local shellCommand "powershell.exe -command"
	}
	else {
		local osCat "cat"
		local shellCommand ""
	}
	
	**** Write out the command string
	local myCommand "echo 'Setting up directory structure... '; `osCat' `remoteDirs'| ssh `host' 'bash -s';"
	local myCommand "`myCommand' echo 'Copying work file... '; scp -q `workJob' `host':~/`remoteDir'/scripts/_workJob.do; echo 'Done!';"
	if "`dloc'" == "local" {
		local myCommand "`myCommand' echo 'Copying data... '; scp -q `dfile' `host':~/`remoteDir'/data/initial/;echo 'Done!';"
	}
	local myCommand "`myCommand' scp C:/Users/goshev/Desktop/gitProjects/parallelize/assets/stataScripts/_runBundle.do `host':~/`remoteDir'/scripts/; echo 'Done!';"
	local myCommand "`myCommand' echo 'Submitting masterJob... '; `osCat' `remoteSubmit' | ssh `host' 'bash -s';"
	
	*** Execute the command
	shell `shellCommand' "`myCommand'"
	
	/* OLD FUNCTIONING VERSION
	
	
	if "`c(os)'" == "Windows" {
		local myCommand "echo 'Setting up directory structure... '; Get-Content -Raw `remoteDirs' | ssh `host' 'bash -s'; echo 'Done!';"
		local myCommand "`myCommand' echo 'Copying work file...'; scp `workJob' `host':~/`remoteDir'/scripts/_workJob.do; echo 'Done!'"
		if "`dloc'" == "local" {
			local myCommand "`myCommand' echo 'Copying data...'; scp `dfile' `host':~/`remoteDir'/data/initial; echo 'Done!'"
		}
		shell powershell.exe -noexit -command "`myCommand'"
	}
	*/
	
	
	
	
	
	/*		
			
			
	*** Run remote script on cluster and move data (if needed)
	if "`c(os)'" == "Windows" {
		shell powershell.exe -noexit -command "echo 'Setting up directory structure... '; Get-Content -Raw `remoteDirs' | ssh `host' 'bash -s'; echo 'Done!';"
		shell powershell.exe -noexit -command "echo 'Copying work file...'; scp `workJob' `host':~/`remoteDir'/scripts/_workJob.do; echo 'Done!'"
		if "`dloc'" == "local" {
			shell powershell.exe -noexit -command "echo 'Copying data...'; scp `dfile' `host':~/`remoteDir'/data/initial; echo 'Done!'"
		}
		* shell powershell.exe -command "echo 'Submitting masterJob... '; Get-Content -Raw `remoteSubmit' | ssh `host' 'bash -s'; echo 'Done!'"
		
		
		/*
		* | ssh `host' 'bash -s'"
		* shell powershell.exe -noexit -command "Get-Content `remoteScript' | ssh `host' 'bash -s'"
		
		* shell powershell.exe -noexit -command "ssh `host' 'mkdir `remoteDir''; Get-Content `toCopyOver' | ssh `host' 'cat > ~/`remoteDir'/jobWork.do'"
		* Get-Content `pbsSubmit' | ssh sirius 'bash -s'"
		*shell powershell.exe -noexit -command "ssh `host' 'mkdir `mydir'; printf '`jobWork'' > ~/`remoteDir'/jobWork.do'"
		* shell powershell.exe -noexit -command "ssh `host' 'mkdir `mydir'; echo 'this is a test' ~/`remoteDir'/mytest.txt'"
		*/
	}
	else {
		
		*shell echo "this is a test" | ssh sirius 'cat > ~/mytest.txt'
	}
	*/
	
end
	

	
	
/*
local test "con(configFile = 'c:\Users\goshev\Desktop\gitProjects\parallelize\config' profile='sirius')"
_parseSpecs "`test'"
local test "con(configFile = '~/Desktop/gitProjects/parallelize/config' profile='sirius')"
_parseSpecs "`test'"

sreturn list
*/
exit




*** Format of connection string:
**** con([configFile = "<path/filename>" profile="<string>"]|[ssh="<hostName>"])
*** Examples:
**** con(configFile = "c:\Users\goshev\Desktop\gitProjects\parallelize\config" profile="sirius") 
**** con(ssh="sirius")

*** Format of individual job specs:
**** job(nodes="" ppn="" walltime="" jobname="") // qsub -l and -N arguments

*** Format of data specs:
**** data(inFile="" loc="<local | cluster | box>") // fname=~/path/filename

*** Format of execution specs:
**** exec(nrep="" progUrl="")



