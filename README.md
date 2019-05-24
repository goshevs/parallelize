# Stata package `parallelize`


*Lead developer and maintainer*: Simo Goshev  
*Developers*: Jason Bowman   
*Group*: BC Research Services


## Introduction

Although a fairly large number of commands in Stata are internally parallelized,
the speed of execution of specific algorithms such as bootstrapping, jackknifing and imputation 
could be accelerated by utilizing a computing cluster. The aim of package `parallelize` is to help researchers 
with parallelizing their analyses and submitting jobs directly from their local 
copy of Stata to the Linux computing cluster at Boston College (and potentially any
cluster running Torque(PBS)).



## Installation


To load package `parallelize`, include the following line in your do file:

```
do "https://raw.githubusercontent.com/goshevs/parallelize/master/ado/parallelize.ado"
```

<br>

## Update on our development effort


Over the past several months, we reached a couple of important milestones:

1. Pulling data directly from Box, thus eliminating a series of intermediate steps. 
We are currently developing the Stata interface to python and also aim to provide 
seemless uploading functionality. 

2. Developed and tested successfully the job submission, monitoring and
output collection functionality (currently streamlining query and collection).

3. Added support for [`pchained`](https://github.com/goshevs/pchained) and user-written routines
via script importation.

4. Added a post-parallelize program for submitting job-related requests to the cluster.
Currently supports requests for progress checking and output retrieval.


**Development continues!**

<br>

## Command `parallelize`

`parallelize` is used to define a connection, decribe the specifics of the job and
submit jobs to the computing cluster

### Syntax

```
parallelize, CONspecs(string) [JOBspecs(string) ///
             DATAspecs(string) imports(string) ///
             EXECspecs(string)]: command

```
<br>

`parallelize` takes the following arguments:

**Required**

| argument    | description            |
|-------------|------------------------|
| *CONspecs*  | connection specification; two flavors, see below for syntax |
| *command*   | command to be parallelized on the cluster |


<br>

**Optional and conditionally required arguments:**

| argument       | description            |
|----------------|------------------------|
| *JOBspecs*     | the specification of a parallel job; see below for syntax |
| *DATAspecs*    | specification of the data to be used; see below for syntax |
| *imports*      | location of work, aggregation and monitoring files; see below for syntax |
| *EXECspecs*    | execution specifications; see below for syntax |


<br>


**Syntax for `CONspecs`**

`CONspecs` can be specified in two ways:

- `con(configFile="" profile="")`, where
	- `configFile` is the path and file name of the configuration file to be used by 
	`ssh` to connection to the cluster
	- `profile` is the name of the profile in the configuration file to be used, or
- `con(sshHost="")`, where:
	- `sshHost` is the name of the host in the ssh `config` file located in `.ssh/` to be 
	used to connect to the cluster

The configuration file should be specified in 
[this](https://github.com/goshevs/parallelize/blob/devel/config) format.
 
<br>


**Syntax for `JOBspecs`**

`JOBspecs` defines the resource requirements for a parallel job. It has the following syntax:

`job(nodes="" ppn="" pmem="" walltime="" jobname="")`

where:

- `nodes` is the number of nodes requested
- `ppn` is the number of virtual processors per node 
- `pmem` is the RAM per processor
- `walltime` is the length of time allocated to the job, or job's runtime
- `jobname` is the name that will be applied to all parallel jobs

<br>


**Syntax for `DATAspecs`**

`DATAspecs` defines the data file and its location. It is specified in the following way:
 
`data(inFile="" loc="" argPass="")`

where:

- `inFile` should include the path and name of the data file
- `loc` takes the values of `local`, `cluster`, or `box` to indicate where the
data file is housed.
- `argPass` takes a string with information that the user wishes to pass to their do files.
This is an optional argument.

<br>


**Syntax for `imports`**

`imports` defines the location of work, aggregation and monitoring files. It is specified in the following way:
 
`imports(work="" coll="" mon="")`

where:

- `work` should include the path and name of the do file to be executed by 
each worker on the cluster
- `coll` should include the path and name of the do file that instructs Stata how to 
combine the output provided by the workers
- `mon` should include the path and name of the do file that instructs Stata how to
monitor the submission and re-submit jobs if necessary

There are special rules for writing these import files. More details to come.
 
<br>


**Syntax for `EXECspecs`**

`EXECspecs` defines execution parameters. It has the following syntax:

`exec(nrep="" pURL="" cbfreq="" email="" )`

where: 

- `nrep` is the number of parallel jobs needed
- `pURL` is the URL of a `do` or `ado` file which has to be imported prior to running `command`. 
This is an optional argument
- `cbfreq` is the callback frequency of the monitoring process (could be defined in seconds, minutes, hours and days)
- `email` instructs Torque to send an email to the specified email address once all jobs are completed.

<br>

## Command `callCluster`

`callCluster` is used to send requests to the cluster. Currently the program 
supports requests for checking progress and retrieving output.


### Syntax

```
callCluster, Request(string asis) [CONspecs(string asis) JOBspecs(string asis) 
                                  OUTloc(string asis) KEEPremote]
	
```
<br>

`callCluster` takes the following arguments:

**Required**

| argument    | description            |
|-------------|------------------------|
| *Request*   | type of request; currently `checkProgress` and `pullData` are supported |

<br>

**Optional and conditionally required arguments:**

| argument       | description            |
|----------------|------------------------|
| *CONspecs*     | connection specification; syntax identical to the one used in `parallelize` |
| *JOBspecs*     | takes `jobname` is an agrument and its syntax is `job(jobname="")`; `jobname` is the name of the job of interest |
| *OUTloc*       | the directory on the user's machine where output should be copied to; default is `~/Desktop` |
| *KEEPremote*   | instructs Stata to keep the job directorty and related files on the cluster; by default Stata will erase all related files |

Both `CONspecs` and `JOBspecs` are required arguments if `callCluster` is not 
run immediately after `parallelize` or the `sreturn` has been cleared.

<br>


## Examples

```
*** Define basepath
local pathBasename "~/Desktop/gitProjects/parallelize"

*** Load the ado's
do "`pathBasename'/ado/parallelize.ado"  // we should pull this from gitHub


************************************
*** GENERIC BOOTSTRAP 

sysuse auto
save "`pathBasename'/examples/data/myboot"

*** Define locations
local locConf "`pathBasename'/config/config1"
local locData "c:/Users/goshev/Desktop/gitProjects/parallelize/examples/data/myboot.dta"
local locWork "`pathBasename'/imports/mybootWork.do"
local locColl "c:/Users/goshev/Desktop/gitProjects/parallelize/imports/mybootCollect.do"  
local locMon  "c:/Users/goshev/Desktop/gitProjects/parallelize/imports/genericMonitor.do"
local eMailAddress "" 

*** Execute custom command in parallel
parallelize,  /// 
        con(sshHost="sirius") /// con(configFile = "`locConf'"  profile="sirius") ///  
        job(nodes="1" ppn="1" pmem="1gb" walltime="00:05:00" jobname="myBoot")  ///
        data(path= "`locData'" loc="local") ///
        imports(work="`locWork'" coll="`locColl'" mon="`locMon'") ///
        exec(nrep="5" cbfreq="30s" email="`eMailAddress'"): ///
        regress price mpg trunk headroom i.foreign, robust
		
		
*** Check progress
callCluster, r(checkProgress)

*** Retrieve data
callCluster, r(pullData)

```
