*** Examples

local pathToAdos "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathToAdos'/myTestCommand.ado"
do "`pathToAdos'/parallelize.ado"


*** Behavior under parallelize
*parallelize, con(sshHost="sirius"): mytest myvar, c(sum)

*** Define locations

local locConf "~/Desktop/gitProjects/parallelize/config"
local locData "~/Desktop/myTestData.dta"
local locProg "https://raw.githubusercontent.com/goshevs/pchained/master/pchained.ado"

noi parallelize,  /// 
        con(configFile = "`locConf'"  profile="cluster1") ///
        job(nodes="1" ppn="1" walltime="00:10:00" jobname="myTest")  ///
		data(file= "`locData'" loc="local") ///
		exec(nrep="10" pURL = "`locProg'"): ///
        mytest myvar, c(sum)

sreturn list

exit

*** Behavior on its own
mytest myvar, c(sum)
