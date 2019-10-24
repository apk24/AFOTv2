import subprocess as sp
import shutil
import sys
import string
import os
import time
import logging as log


assert sys.version_info >= (3,6), "Python version 3.6 or higher is required to run this script"

assert len(sys.argv) == 9, "Check argument count"

afName = str(sys.argv[1])
assert len(afName) >= 4, "Ensure afname has file extension (4char minimum)" + str(afName)

Re = int(sys.argv[2])
assert Re > 0, "Ensure Re > 0" + str(Re)

mach = float(sys.argv[3])
assert (mach < 1) and (mach > 0), "Ensure subsonic plane that moves " + str(mach) 

alphaStart = float(sys.argv[4])
alphaEnd = float(sys.argv[5])
alphaStep = float(sys.argv[6])

assert (alphaEnd - alphaStart) >= alphaStep, "Double check alpha min max and step"

outFile = str(sys.argv[7])
assert len(outFile) >= 4, "Ensure outFile has file extension (4char minimum)"

debug = bool(int(sys.argv[8]))
if debug:
	log.basicConfig(level=log.DEBUG, filemode='a', filename="xfoil.py.log", format="{%(process)s}::[%(asctime)s]::%(levelname)s:\t%(message)s")
else:
	log.basicConfig(level=log.WARNING, filemode='a', filename="xfoil.py.log", format="{%(process)s}::[%(asctime)s]::%(levelname)s:\t%(message)s")

def xfrange(start, stop, step):
	if(start <= stop):
		while start <= stop:
			yield start
			start += step
	else:
		while start >= stop:
			yield start
			start -= step

log.info("Basic setup complete, opening xfoil")

ps = sp.Popen(['xfoil.exe'],
			bufsize=0,
			stdin=sp.PIPE,
			stdout=(None if debug else sp.DEVNULL),
			stderr=None)

def issueCmd(cmd,echo=debug):
	#(outpt, err) = ps.communicate((cmd + "\r\n").encode('utf-8'))
	#if echo:
	#	print(ps.stdout.read())
	ps.stdin.write((cmd + "\r\n").encode('utf-8'))
	if echo:
		print(cmd)
	log.debug(cmd)
	time.sleep(.2)
	#	print(ps.stdout.read())
time.sleep(1)

if(not debug):
	issueCmd('plop')
	issueCmd('G')
	issueCmd('')

log.debug("Loading airfoil")

issueCmd('load ' + afName)
issueCmd('gdes')
issueCmd('cadd')
issueCmd('')
issueCmd('')
issueCmd('')
issueCmd('')
issueCmd('')
issueCmd("pane")

log.debug("Starting oper")

issueCmd("oper")
issueCmd("Re " + str(Re))
issueCmd("mach " + str(mach))
issueCmd("Type 1")
issueCmd("Visc")
issueCmd('iter 500')

log.info("Starting pacc with filename " + outFile)

issueCmd("pacc")
if debug:
	print("Using: " + outFile)
if os.path.isfile(outFile):
	log.warning(outFile + " already exists. Deleting.")
	os.remove(outFile)
issueCmd(outFile)
#os.remove('dump.tmp')
issueCmd('')

issueCmd('cl -.01')
issueCmd('cl 0')
issueCmd('cl .01')

center = (alphaStart + alphaEnd)/2
upperQuarter = (center + alphaEnd)/2
lowerQuarter = (center+alphaStart)/2

#'''
stepCounter = 0
for a in xfrange(center - alphaStep, upperQuarter, alphaStep):
	issueCmd('alfa ' + "{0:.3g}".format(a))
	if(not stepCounter % 5):
		issueCmd('init')

issueCmd('init')
for a in xfrange(center + alphaStep, lowerQuarter, alphaStep):
	issueCmd('alfa ' + "{0:.3g}".format(a))
	if(not stepCounter % 5):
		issueCmd('init')

issueCmd('init')
for a in xfrange(upperQuarter - alphaStep, alphaEnd, alphaStep):
	issueCmd('alfa ' + "{0:.3g}".format(a))
	if(not stepCounter % 5):
		issueCmd('init')

issueCmd('init')
for a in xfrange(lowerQuarter + alphaStep, alphaStart, alphaStep):
	issueCmd('alfa ' + "{0:.3g}".format(a))
	if(not stepCounter % 5):
		issueCmd('init')

time.sleep(5)
issueCmd("pacc")
issueCmd('')

issueCmd("quit")

log.info("Quit command issued")

while(not os.path.isfile(outFile)):
	time.sleep(1)


while(not ps.poll() and (time.time()-os.path.getmtime(outFile)) < 120):
	time.sleep(1)
if(not ps.poll()):
	log.warning("120 seconds have passed. Sending sigterm.")
	ps.terminate()

try:
	if(not ps.poll()):
		(out, errs) = ps.communicate(timeout=3)
except (sp.TimeoutExpired):
	log.error("3 minutes since sigterm. Sending sigkill.")
	ps.kill()
	pass

log.debug("xfoil.py exiting")
#'''