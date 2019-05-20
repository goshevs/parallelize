********************************************************************************
*** EXAMPLES

*** This file should be exectuted locally.


*** Define basepath
local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/ado/parallelize.ado"  // we should pull this from gitHub



************************************
*** PCHAINED


*** Denerate data and save it to a file
clear
do "~/Desktop/gitProjects/pchained/simdata.ado"
simdata 1000 3
save "`pathBasename'/examples/data/pchainedData.dta", replace
clear


*** Define locations
** -->  Location of configuration file if needed
local locConf "`pathBasename'/config/config1"
** --> Directory of data file (and possibly file name)(needs a full path for scp to work properly if stored locally)
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/examples/data/pchainedData.dta" 
** --> Location of command to be parallelized; not needed for built-in Stata commands
local locProg "https://raw.githubusercontent.com/goshevs/pchained/parallel/pchained.ado"
** --> Work to be done by a worker on the cluster
local locWork "`pathBasename'/plugins/pchainedWork.do"
** --> Instruction on how to collect/combine worker output (needs a full path for scp to work properly if stored locally)
local locColl "c:/Users/goshev/Desktop/gitProjects/parallelize/plugins/pchainedCollect.do"
** --> Email address to receive communication from Torque
local eMailAddress "" 

*** Execute pchained in parallel
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" pmem="1gb" walltime="00:05:00" jobname="myPchained")  ///
        data(path= "`locData'" loc="local" argPass="id time") ///
		plugins(work="`locWork'" coll="`locColl'") ///
        exec(nrep="5" cbfreq="30s" email="`eMailAddress'" pURL = "`locProg'"): ///
		pchained (s1_i, noimputed scale), i(id) t(time) mio(add(50) chaindots rseed(123456))





************************************
*** CUSTOM SCRIPT


*** Denerate data and save it to a file
clear
set more off
set obs 100

gen id = _n
gen x1 = rnormal() * 100
gen x2 = rnormal()

save "`pathBasename'/examples/data/mytestData", replace
clear


*** Define locations
local locConf "`pathBasename'/config/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/examples/data/mytestData.dta"
local locProg "https://raw.githubusercontent.com/goshevs/parallelize/pchained/ado/mytest.ado"
local locWork "`pathBasename'/plugins/mytestWork.do"
local locColl "c:/Users/goshev/Desktop/gitProjects/parallelize/plugins/mytestCollect.do"  
local eMailAddress "" 

*** Execute custom command in parallel
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" pmem="1gb" walltime="00:05:00" jobname="myTest")  ///
        data(path= "`locData'" loc="local" argPass="irrelevant") ///
        plugins(work="`locWork'" coll="`locColl'") ///
        exec(nrep="5" cbfreq="30s" email="`eMailAddress'" pURL = "`locProg'"): ///
		mytest x1, c(sum)



