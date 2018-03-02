PBKDF2 SHA1 and SHA256 Bruteforcing using OpenCL (GPU, yay!) and Python
(c) B. Kerler 2017-2018

Why
===
- Because bruteforcing PBKDF2 and hashing SHA1/SHA256 using just CPU sucks.
- Because Python itself is very slow for bruteforcing
- Because we'd like to bruteforce using Python and not rely on other
  tools like Hashcat (sorry Atom :D) and do not want to compile c++ first
  
Installation
=============
1. Get python 3.6 64-Bit
2. Download pyopencl-2017.2.2+cl21-cp36-cp36m-win_amd64.whl from
   [Here] (http://www.lfd.uci.edu/~gohlke/pythonlibs/#pyopencl)
3. Download and install the Win32 OpenCL driver (from Intel) from 
   [Here] (http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi)
4. Install pyOpenCL using: python -m pip install pyopencl-2017.2.2+cl21-cp36-cp36m-win_amd64.whl

Run
===
- To test if Library works correctly, run:
  "python test.py" -> to print info
  "python test.py 0" -> to run on first platform
- See test.py for example implementation, Library is in Library folder

Issues
======
- Tested with : Intel CPU and GPU, NVIDIA GTX 1080 Ti, AMD 970
- Limited for max. 32 chars for password, salt and hash (because speed optimized for mobile
  device security)
 
Published under MIT license
Additional license limitations: No use in commercial products without prior permit.

Enjoy !
