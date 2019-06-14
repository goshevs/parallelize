import argparse, subprocess, sys

################################################################################
### Function Definitions

def parseArgs():
    ''' Argument parser '''

    parser = argparse.ArgumentParser(description='Write and submit jobs.', epilog="That's it for now!\n")

    group1 = parser.add_argument_group('PBS job specs')
    group1.add_argument("--name", metavar="", help = "name of job")
    group1.add_argument("--nodes", metavar="", help = "number of nodes")
    group1.add_argument("--ppn", metavar="", help = "processors per node")
    group1.add_argument("--pmem", metavar="", help = "memory per processor")
    group1.add_argument("--walltime", metavar="", help = "walltime of the job, HHH:MM:SS")

    group2 = parser.add_argument_group('Spooler specs')
    group2.add_argument("-d", metavar="", help = "remote directory")
    group2.add_argument('-f', metavar = '', help = 'argument file')
    group2.add_argument('-t', metavar="", help = 'type of call: basic, iterative, complex')
    group2.add_argument("-r", metavar="", help = "replications")
    group2.add_argument('--advanced-args', metavar = '', help = 'argument list')

    group3 = parser.add_argument_group('Monitor specs')
    group3.add_argument("-m", metavar="", help = "monitor file")
    group3.add_argument("-u", metavar="", help = "user name")
    group3.add_argument("--call-back", metavar="", help = "callback delay")
    group3.add_argument("--mon-args", metavar="", help = "monitor arguments")

    group4 = parser.add_argument_group('Collector specs')
    group4.add_argument("-c", metavar="", help = "collect file")
    group4.add_argument("--col-args", metavar="", help = "collector arguments")
    group4.add_argument("--email", metavar="", help = "user email address")

    group5 = parser.add_argument_group('Work specs')
    group5.add_argument("-j", metavar="", help = "PBS job id")
    group5.add_argument("-w", metavar="", help = "work file")
    group5.add_argument("--work-args", metavar="", help = "work arguments")

    group6 = parser.add_argument_group('Executable specs')
    group6.add_argument("-e", metavar="", help = "executable")
    group6.add_argument("--pbs-modules", metavar="", help = "pbs module(s) required")

    args = parser.parse_args()

    return([args, ' '.join(sys.argv[1::])])

def readfile(filename):
    with open(filename, 'r') as f:
        myargs = f.readline()
    return(myargs)

def _executable(module, prog):
    ''' Loads modules and fires up batch executable '''

    myExec = 'module load ' + module + ' moab\n'
        
    if prog == 'stata':
        myExec = myExec + 'stata-mp -b '
    elif prog == 'R':
        myExec =  myExec + 'Rscript --vanilla '
    elif prog in ['python2', 'python3']:
        myExec =  myExec + prog + ' '
    else:
        print(prog + ' is not supported')
        sys.exit(1)
        
    return (myExec)



### Defining a job class
class Job:         
    def __init__(self, args):
        self.args = args[0]
        self.commandArgs = args[1] 
        self.logDir = 'cd ' + self.args.d + '/logs\n'
        
    def parameters(self, jobType):
        nodes = '1'
        ppn = '1'
        pmem = '1gb'
        wt = '120:00:00'

        if jobType == "work":
            nodes = self.args.nodes
            ppn = self.args.ppn 
            pmem = self.args.pmem
            wt = self.args.walltime            

        jobSpecs = ('#PBS -N ' + jobType + '_' + self.args.name +
                    ' -S /bin/bash -l ' +
                    'nodes=' + nodes + ':ppn=' + ppn + ',pmem=' + pmem +
                    ',walltime=' + wt)
            
        if jobType == 'collect':
            jobSpecs = jobSpecs + ' -m e -M ' + self.args.email

        return(jobSpecs + '\n')
    
        
    def task(self, jobType):

        fargs = ''
        execLine = _executable(self.args.pbs_modules, self.args.e)

        if jobType == 'monitor':
            call = 'monitorSubmit.py ' + self.commandArgs 
            execLine =  _executable('python', 'python3')
                
        elif jobType == 'work':
            call = self.args.w


        elif jobType == 'collect':
            call = self.args.c
            if self.args.col_args is not None:
                fargs = '#PBS -F ' + self.args.col_args + '\n'
                    
        jobContents = (self.parameters(jobType) + fargs + self.logDir  +
                           execLine + self.args.d + '/scripts/' + call +'\n')        

        return(jobContents)
    
    def spooler(self, call):

        if call == 'basic':
            qsubSpecs = 'qsub -t ' + self.args.r + ' -F $PBS_JOBID '  + self.args.work_args
            qsubDone  = '\n'
            
        elif call == 'iterative':
            qsubSpecs = ('for ((i=1;i<=' + self.args.r + ';i++)); do;\n' +
                             'qsub -F $PBS_JOBID $i ' + self.args.work_args)
            qsubDone  = 'done\n' 

        elif call == 'complex':
            if self.args.f is not None:
                advanced_args = readfile(self.args.f).replace('\n','')
            elif self.args.advanced_args is not None:
                advanced_args = self.args.advanced_args
            else:
                print('No advanced arguments provided')
                sys.exit(1)
                
            qsubSpecs = ('for i in ' + advanced_args + '; do;\n' +
                            'qsub -F $PBS_JOBID $i ' + self.args.work_args
                             )
            qsubDone  = 'done\n'

        ## Construct the string
        jobContents = (self.logDir + self.parameters('spooler') + self.logDir +
                           qsubSpecs + ' <<- \\EOF4 ' + self.task('work') + 'EOF4\n' +
                           qsubDone )

        return(jobContents) 
   
    def master(self):
        jobContents = (
                self.logDir + 
                'qsub <<- \\EOF1 ' + self.parameters('master') + 
                self.logDir + 
                'spooler=$(qsub <<- \\EOF2 ' + self.spooler(self.args.t) + 'EOF2)\n' + 
                self.logDir + 
                'monitor=$(qsub -W depend=afterok:$spooler <<- \\EOF3 ' + self.task('monitor') +'EOF3)\n' +
                self.logDir + 
                'qsub -W depend=afterok:$monitor <<- \\EOF5 ' + self.task('collect') +'EOF5\n' + 'EOF1'
                )
        return(jobContents)

class Monitor:

    def __init__(self, args):
        self.args = args
        
    def checkJobs(self):

        baseStr = 'showq -n -{} | grep ' + self.args.u + ' | grep ' + self.args.name + ' | wc -l'
        cStr = [baseStr.format(i) for i in ['r', 'i']]

        response = []
        for i in cStr:
            p = subprocess.Popen(i, stdout=subprocess.PIPE, shell= True)
            response.append(int(p.communicate()[0]))
       
            check = sum(response)
            return([check, response])

    def checkOutput(self):
        baseStr = '~/' + self.args.d + 'data/output/data | wc -l' 
        p = subprocess.Popen(baseStr, stdout=subprocess.PIPE, shell= True)
        return(int(p.communicate()[0]))     

    def checkStatus(self):
        check = self.checkJobs()[0]
        while check != 0:     
            sleep(call_back)
            check  = self.checkJobs()[0]




    









# class Job:         
#     def __init__(self, args):
#         self.args = args
#         self.logDir = 'cd ' + self.args.d + '/logs\n'
        
#     def jobParms(self, jobType):
#         nodes = '1'
#         ppn = '1'
#         pmem = '1gb'
#         wt = '120:00:00'

#         if jobType == "work":
#             nodes = self.args.nodes
#             ppn = self.args.ppn 
#             pmem = self.args.pmem
#             wt = self.args.walltime            

#         jobSpecs = ('#PBS -N ' + jobType + '_' + self.args.n +
#                     ' -S /bin/bash -l ' +
#                     'nodes=' + nodes + ':ppn=' + ppn + ',pmem=' + pmem +
#                     ',walltime=' + wt)
            
#         if jobType == 'collect':
#             jobSpecs = jobSpecs + ' -m e -M ' + self.args.email

#         return(jobSpecs + '\n')
    
        
#     def simpleJob(self, jobType):

#         if jobType == 'work':
#             callFile = self.args.w
#         elif jobType == 'monitor':
#             callFile = self.args.m
#         elif jobType == 'collect':
#             callFile = self.args.c
    
#         jobContents = (self.jobParms(jobType) + self.logDir  +
#                            _executable(self.args.pbs_modules, self.args.e ) +
#                            self.args.d + '/scripts/' + callFile
#                            )
            
#         return(jobContents)

#     def spooler(self, call):
#         if call == 'master':
#             jobContents = (
#                 self.logDir + self.jobParms('spooler') + self.logDir +
#                 'qsub -t ' + self.reps.r + ' -F <this is where arguments live> ' +
#                 ' <<- \\EOF4 ' + self.simpleJob('work') + 'EOF4\n' +
#                 )
#         elif call == 'monitor':
#              jobContents = (
#                 self.logDir + self.jobParms('spooler') + self.logDir +
#                ## conditions for running == number of loops or specific observations??? HAve to think about that!!!
#                 'qsub -F <this is where arguments live>  <<- \\EOF4 ' + self.simpleJob('work') + 'EOF4\n'
#                 )
#         return(jobContents)
    
#     def master(self):
#         jobContents = (
#                 self.logDir + 
#                 'qsub <<- \\EOF1 ' + self.jobParms('master') + 
#                 self.logDir + 
#                 'spooler=$(qsub <<- \\EOF2 ' + self.spooler('master') + 'EOF2)\n' + 
#                 self.logDir + 
#                 'monitor=$(qsub -W depend=afterok:$spooler <<- \\EOF3 ' + self.simpleJob('monitor') +'EOF3)\n' +
#                 self.logDir + 
#                 'qsub -W depend=afterok:$monitor <<- \\EOF5 ' + self.simpleJob('collect') +'EOF5\n' + 'EOF1'
#                 )
#         return(jobContents)


