#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# (c) 2021 B. Kerler
# MIT License

import threading
import sys
import hashlib
import argparse
import queue
from time import perf_counter
from binascii import hexlify
from Library import opencl
from Library.passwordutils import passwordutils


def verify_set(wordlist, key, salt, hash_val):
    for pwd in wordlist:
        pw = hashlib.pbkdf2_hmac('SHA256', password=pwd, salt=salt, iterations=10000, dklen=32)
        if hash_val in hashlib.sha1(pw).hexdigest()[:8]:
            print(f'[+] correct password: {pwd}', flush=True)
            return pwd
    return b""


def setup_args():
    parser = argparse.ArgumentParser(description='PW Bruteforce-Tool V1.0 (c) B. Kerler')
    parser.add_argument("-p", "--platform", required=False, help='OpenCL platform id.')
    parser.add_argument("-b", "--batch_size", required=False, help='Define batch_size/workgroupsize if necessary.')
    parser.add_argument("-m", "--minlen", required=False, help='Define PW minimum length.')
    parser.add_argument("-x", "--maxlen", required=False, help='Define PW maximum length.')
    args = parser.parse_args()
    return args


class brute:
    def __init__(self):
        self.totalthreads = None
        self.stop = False
        self.passwords=queue.Queue()
        self.flag = None
        self.key = None
        self.salt = None
        self.hash_val = None
        self.computeunits = None
        self.accel = None
        self.totalthreads = None
        self.iterations = None
        self.args = setup_args()
        if self.args.batch_size is not None:
            self.totalthreads = self.args.batchsize
        if self.args.minlen is not None:
            self.minlen = self.args.minlen
        else:
            self.minlen = 8

        if self.args.maxlen is not None:
            self.maxlen = self.args.maxlen
        else:
            self.maxlen = 16

        self.debug = 0
        if self.args.platform is not None:
            self.platform = self.args.platform
        else:
            self.platform = 0

        self.opencl_algo = opencl.opencl_algos(self.platform, self.debug, write_combined_file=False,
                                               inv_memory_density=1)

    def verifypws(self):
        pwcount = 0
        start_time = perf_counter()
        while not self.passwords.empty():
            pwlist = []
            for i in range(0, self.totalthreads):
                if not self.stop:
                    pw = self.passwords.get()
                    pwlist.append(pw)
                    pwcount += 1
                else:
                    while not self.passwords.empty():
                        pw = self.passwords.get()
                        pwlist.append(pw)
                        pwcount += 1
                    break

            """
                Implement your algo here
            """
            results = self.opencl_algo.cl_pbkdf2(self.ctx_pbkdf2, pwlist, self.salt, self.iterations, 32)
            digests = []
            for result in results:
                digests.append(result)
            """
                End of implementation
            """

            if len(pwlist) > 0:
                elapsed_time = perf_counter() - start_time
                calcedpw = self.totalthreads / elapsed_time
                print(f"Current try : {pwlist[0].decode('utf-8')}, {calcedpw} PWs/s, " +
                      f"{self.totalthreads} PWs/Thread, {pwcount} total PWs.")
                start_time = perf_counter()

            """
                Implement your verification here
            """
            for number, sha in enumerate(digests):
                if self.hash_val == sha:
                    print(f'[+] found password: {pwlist[number]}')
                    return pwlist[number]
        return None

    def init_gcpu(self,salt,hash_val,iterations):
        self.salt = salt
        self.hash_val = hash_val
        self.iterations = iterations
        # init opencl instance
        self.ctx_pbkdf2=self.opencl_algo.cl_pbkdf2_init("sha256",len(self.salt),32)

        if self.totalthreads is None:
            self.computeunits = self.opencl_algo.opencl_ctx.computeunits
            self.accel = max(self.computeunits // 4 * 4 // 4, 1)
            self.totalthreads = self.opencl_algo.opencl_ctx.workgroupsize * self.accel
            print(f"Using Thread size of {self.totalthreads}")

    def stopthread(self):
        self.stop = True

    def run(self):
        sys.stdin = sys.stdin.detach()
        self.threadLock = threading.Lock()
        thread1 = passwordutils(self.stopthread, self.threadLock, self.passwords, self.totalthreads, self.minlen, self.maxlen)
        #thread2 = passwordutils(self.passwords, self.totalthreads, self.minlen, self.maxlen)
        #thread3 = passwordutils(self.passwords, self.totalthreads, self.minlen, self.maxlen)
        #thread4 = passwordutils(,self.passwords, self.totalthreads, self.minlen, self.maxlen)
        thread1.start()
        #thread2.start()
        #thread3.start()
        #thread4.start()
        # We wait here for first passwords to arrive
        while self.passwords.empty():
            pass
        start_time = perf_counter()
        res = self.verifypws()
        thread1.join()
        #thread2.join()
        #thread3.join()
        #thread4.join()
        elapsed_time = perf_counter() - start_time
        print(f"Total time : %f" % elapsed_time)

        if res == -1 or res is None:
            print("No password found")
            exit(0)


if __name__ == '__main__':
    tb = brute()
    salt=b"\x12\x34\x56\x78"
    iterations=10000
    hash_val=hashlib.pbkdf2_hmac("SHA256",b"testtest",salt,iterations,32)
    tb.init_gcpu(salt,hash_val,iterations)
    tb.run()
