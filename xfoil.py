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
	log.basicConfig(level=log.INFO, filemode='a', filename="xfoil.py.log", format="{%(process)s}::[%(asctime)s]::%(levelname)s:\t%(message)s")

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
			stdin=sp.PIPE,
			stdout=(None if debug else sp.DEVNULL),
			stderr=None,
			universal_newlines=True,
			bufsize=1)

log.info("PID of child process is " + str(ps.pid))

def issueCmd(cmd,echo=debug):
	if(ps.poll() is not None):
		log.critical("Dead process can't accept a command")
		raise RuntimeError("Child process quit unexpectedly")
	ps.stdin.write(cmd + "\n")
	if echo:
		print(cmd)
		log.debug(cmd)
	time.sleep(.2)
time.sleep(1)


try:
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
	time.sleep(10)

	issueCmd('init')
	for a in xfrange(center + alphaStep, lowerQuarter, alphaStep):
		issueCmd('alfa ' + "{0:.3g}".format(a))
		if(not stepCounter % 5):
			issueCmd('init')
	time.sleep(10)

	issueCmd('init')
	for a in xfrange(upperQuarter - alphaStep, alphaEnd, alphaStep):
		issueCmd('alfa ' + "{0:.3g}".format(a))
		if(not stepCounter % 5):
			issueCmd('init')
	time.sleep(10)

	issueCmd('init')
	for a in xfrange(lowerQuarter + alphaStep, alphaStart, alphaStep):
		issueCmd('alfa ' + "{0:.3g}".format(a))
		if(not stepCounter % 5):
			issueCmd('init')
	time.sleep(10)

	time.sleep(5)
	issueCmd("pacc")
	issueCmd('')

	issueCmd("quit")

	log.info("Quit command issued")

	fnfCounter = 0
	while(not os.path.isfile(outFile) and fnfCounter < 6):
		log.warning("Outfile not found, waiting ten seconds")
		time.sleep(10)
		fnfCounter = fnfCounter + 1

	if fnfCounter >= 6:
		log.critical("No outfile generated. Sending sigterm.")
		ps.terminate()
	else:
		while(not ps.poll() and (time.time()-os.path.getmtime(outFile)) < 90):
			time.sleep(1)
		if(not ps.poll()):
			log.warning("90 seconds since last filewrite. Sending sigterm.")
			ps.terminate()

	try:
		if(not ps.poll()):
			out, errs = ps.communicate(input=None, timeout=30)
	except (sp.TimeoutExpired) as toe:
		log.error("30 seconds since sigterm. Sending sigkill.")
		try:
			ps.kill()
			out, errs = ps.communicate()
		except Exception as e:
			raise e from toe
		pass
except Exception as e:
	log.critical("Uncaught Exception: " + str(e))

log.debug("xfoil.py exiting")
#'''