import parallelize as p
import sys, subprocess
 
        
if __name__ == '__main__':
    
    print('\nCommand arguments: ' + ' '.join(sys.argv[1::]) + '\n')
    args = p.parseArgs()[0]

    
    ### This whole thing should be a while loop
    
    #p.Monitor(args).checkStatus()

    ## Simple check:
    if args.m is None:
        #nfiles = p.Monitor(args).checkOutput()
        nfiles = 0
        diff = int(args.r) - nfiles
        if diff != 0:
            print('\nRefire SPOOLER JOB:\n' + p.Job(args).spooler('complex'))
            
    else:
        print('Running monitoring job in ' + args.m)

    #p.Monitor(args).checkStatus()
