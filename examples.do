*** Examples

local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/myTestCommand.ado"
do "`pathBasename'/parallelize.ado"


*** Behavior under parallelize
*parallelize, con(sshHost="cluster1"): mytest myvar, c(sum)

*** Define locations
local locConf "`pathBasename'/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/myData.dta"  // full path is required (for scp)
local locProg "https://raw.githubusercontent.com/goshevs/parallelize/devel/mytest.ado"


*** Generate data
do "`pathBasename'/simdata.do"
save "`pathBasename'/myData", replace
clear

capture erase "~/Desktop/test.do"

*** Run code
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" walltime="00:10:00" jobname="myTest")  ///
        data(file= "`locData'" loc="local") ///
        exec(nrep="10" pURL = "`locProg'"): mytest x1, c(sum)

sreturn list

exit

*** Behavior on its own
* mytest myvar, c(sum)

*
* con(configFile = "`locConf'"  profile="cluster1") ///
        
		  con(configFile = "`locConf'"  profile="sirius") ///
