import subprocess as sp
import shutil
import sys
import string
import os
import time



assert sys.version_info >= (3,6), "Python version 3.6 or higher is required to run this script"

afNum = int(sys.argv[1])
debug = bool(int(sys.argv[2]))

if os.path.isfile('./airfoils/naca' + str(afNum).zfill(4) + '-xf.dat'):
	quit()

ps = sp.Popen(['xfoil.exe'],
			bufsize=-1,
			stdin=sp.PIPE,
			stdout=(None if debug else sp.DEVNULL),
			stderr=None)


def issueCmd(cmd,echo=debug):
	ps.stdin.write((cmd + "\r\n").encode('utf-8'))
	if echo:
		print(cmd)

if(not debug):
	issueCmd('plop')
	issueCmd('G')
	issueCmd('')

issueCmd('naca')
issueCmd(str(afNum).zfill(4))
issueCmd('save ./airfoils/NACA' + str(afNum).zfill(4) + '-xf.dat' )

issueCmd("quit")



try:
	if(not ps.poll()):
		(out, errs) = ps.communicate(timeout=10)
except (sp.TimeoutExpired):
	ps.kill()
	pass
#'''