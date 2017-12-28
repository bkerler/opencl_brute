PBKDF2 SHA1 and SHA256 Bruteforcing using OpenCL (GPU, yay!) and Python
(c) B. Kerler 2017

Why
===
- Because bruteforcing PBKDF2 using just CPU sucks.
- Because Python alone is very slow for bruteforcing
- Because we'd like to bruteforce using Python and not reply on other
  tools like Hashcat (sorry Atom :D) and do not want to compile c++ first
  
Installation
=============
1. Get python 3.6 64-Bit
2. Download pyopencl-2017.2.2+cl21-cp36-cp36m-win_amd64.whl from
   [Here] (http://www.lfd.uci.edu/~gohlke/pythonlibs/#pyopencl)
3. Download and install the Win32 OpenCL driver (from Intel) from 
   [Here] (http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi)
4. Install pyOpenCL using: python -m pip install pyopencl-2017.2.2+cl21-cp36-cp36m-win_amd64.whl

Issues
======
- Tested only with Intel CPU and GPU
- AMD and NVIDIA GPUs might/will need some code changes (workgroup optimizations)
- Limited for max. 32 chars for password and salt (because speed optimized for mobile
  device security)
 
Published under MIT license

Enjoy !