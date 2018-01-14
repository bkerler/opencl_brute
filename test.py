import sys
from Library import opencl

def main(argv):
    if (len(argv)<2):
        print("OpenCL PBKDF2 implementation test (c) B.Kerler 2018")
        print("---------------------------------------------------")
        info=opencl.opencl_information()
        info.printplatforms()
        print("\nPlease run as: python test.py [platform number]")
        exit(0)

    # Input values for PBKDF2 SHA1 to be hashed
    passwordlist = [b'password', b'default_password']
    salt = b'1234'
    iterations = 1000
    debug = 0
    
    print("Init opencl...")
    platform = int(argv[1])
    pbkdf2 = opencl.pbkdf2_opencl(platform, salt, iterations, debug)
    print("Testing sha1...")
    pbkdf2.compile('sha1')
    result=pbkdf2.run(passwordlist)
    test=False
    if (result[0]=='624720cc0e467b2105352eea65580c4dc93b157a6bc057f1720d3ff57bd8db9f'):
        if (result[1] == '45999865271fbe67280eda4ea79afa3d07adf7bd74b658ba2672b95abc033577'):
            test=True
    if (test==True):
        print ("Ok !")
    else:
        print ("Failed !")
    print("Testing sha256...")
    pbkdf2.compile('sha256')
    result = pbkdf2.run(passwordlist)
    test=False
    if (result[0]=='67f6eb6e2e00dea5e3866a5af9956b9a3005f8daf07a2901c45275b54facf9d5'):
        if (result[1] == 'b3f7b5906bfe21d7e981c6b8cc90aba88f30376fab26305ebe3c083af4cdf976'):
            test=True
    if (test==True):
        print ("Ok !")
    else:
        print ("Failed !")
    # for sha1, result should be ['624720cc0e467b2105352eea65580c4dc93b157a6bc057f1720d3ff57bd8db9f', '45999865271fbe67280eda4ea79afa3d07adf7bd74b658ba2672b95abc033577']
    # for sha256, result should be ['67f6eb6e2e00dea5e3866a5af9956b9a3005f8daf07a2901c45275b54facf9d5', 'b3f7b5906bfe21d7e981c6b8cc90aba88f30376fab26305ebe3c083af4cdf976']
    # End of input values

if __name__ == '__main__':
  main(sys.argv)