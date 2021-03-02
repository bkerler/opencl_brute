import sys
import threading
from time import sleep
from queue import Queue

class passwordutils(threading.Thread):
    def __init__(self, stop, threadLock, passwords:Queue, totalthreads:int, minlen=4, maxlen=16):
        threading.Thread.__init__(self)
        self.minlen = minlen
        self.stop = stop
        self.maxlen = maxlen
        self.passwords = passwords
        self.threadLock = threadLock
        self.totalthreads = totalthreads
        # We start the password generator here as a thread

    def run(self):
        global threadLock
        try:
            while True:
                self.threadLock.acquire()
                buff = sys.stdin.readline()
                self.threadLock.release()
                if buff == b"\n":
                    continue
                elif buff == b"":
                    self.threadLock.acquire()
                    self.stop()
                    self.threadLock.release()
                    while not self.passwords.empty():
                        sleep(1)
                    return
                h = buff.rstrip()
                if self.maxlen < len(h) < self.minlen:
                    continue
                self.threadLock.acquire()
                self.passwords.put(h)
                self.threadLock.release()
                while self.passwords.qsize() > self.totalthreads:
                    if self.passwords.empty():
                        sleep(1)
                        break
                    sleep(0.02)

        except KeyboardInterrupt:
            sys.stdout.flush()
            pass
        return None
