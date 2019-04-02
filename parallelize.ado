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
	foreach arg in nodes ppn walltime jobname {
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
	foreach arg in nrep {
		if "`s(`arg')'" ~= "" {
			local `arg' "`s(`arg')'"
		}
		else {
			noi di _n in r "Please, provide argument `arg' in execution specs"
			exit 489
		}
	}
	
	local url "`s(pURL)'"
	
	*** Compose and transfer content to remote machine
	tempname remoteDir    // directory on remote machine
	_transferAndSubmit "`host'" "`remoteDir'" `"`file'"' `"`loc'"' `"`s(pURL)'"' `"`command'"' "`nrep'"
	
	
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
capture program drop _transferAndSubmit
program define _transferAndSubmit, sclass

	args host remoteDir dfile dloc url command nrep
	
	
	*** LOCATION OF DATA
	if "`dloc'" == "local" {
		if regexm("`dfile'", "^(.+/)*(.+)$") {
			local fName `=regexs(2)'
		}
		local dataLoc "~/`remoteDir'/`fName'"
	}
	else if "`dloc'" == "cluster" {
		local dataLoc "`dfile'"
	}
	else {
		*** box ***
	}
	
	
	*** WORK file
	local doTitle "* This is the work file`=char(10)'"
	local doARgs "args jobID`=char(10)'"
	if "`s(pURL)'" ~= "" {
		local doLoadProg "do `s(pURL)'`=char(10)'"
	}
	local doLoadData "use `dataLoc'`=char(10)'"
	local doWork "`command'`=char(10)'"   // command should have a switch
	*** Here we need instructions for storing the results

	*** Combine all parts
	local jobWork "`doTitle'`doLoadProg'`doLoadData'`doWork'"


	*** REMOTE SCRIPT
	
	*** Set tempfile and file handle to store commands
	tempfile remoteScript 
	tempname scriptHandle
	
	
	*** Compose and write out REMOTE SCRIPT
	file open `scriptHandle' using `remoteScript', write
	file write `scriptHandle' "echo '`jobWork'' > ~/`remoteDir'/_workJob.do;"
	file write `scriptHandle' "wget https://raw.githubusercontent.com/goshevs/parallelize/devel/_runBundle.do -P ./`remoteDir'/; "
	file write `scriptHandle' "cd `remoteDir' && "
	file write `scriptHandle' "`find /usr/public/stata -name stata-mp 2>/dev/null` -b _runBundle.do master ~/`remoteDir' `nrep' && "
	file write `scriptHandle' "echo 'Done!'"
	file close `scriptHandle'

	*shell powershell.exe -noexit -command "Get-Content `pHolder'"
	* shell powershell.exe -noexit -command "ssh `host'"
	
	
	*** If data on local machine
	if "`dloc'" == "local" {
		local dataTransfer `"shell powershell.exe -command "echo 'Copying data to the cluster...'; ssh `host' mkdir `remoteDir'; scp `dfile' `host':~/`remoteDir'/; echo 'Done!'"'
	}
	
	*** Run remote script on cluster and move data (if needed)
	if "`c(os)'" == "Windows" {
		`dataTransfer'
		shell powershell.exe  -noexit -command "echo 'Creating directories and files... '; Get-Content -Raw `remoteScript' | ssh `host' 'bash -s'; echo 'Done!'"
		

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



