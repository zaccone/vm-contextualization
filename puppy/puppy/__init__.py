
import mmap
import os
import StringIO
import sys

import const

class Puppy(object):
    def __init__(self,*args,**kwargs):
        pass


class Template(object):
    """
    Class representing a single template that will be used for
    creating ready to use shell script.
    """

    def __init__(self,fname,flags=const.MEMORY_CACHE):
        self._fname = fname
        self._flags = flags
        flags
        if self._flags & const.MEMORY_CACHE:
            with open(self._fname,'r') as fn:
                self._membuf = fn.read()
                iohandler = StringIO.StringIO
                self._file = iohandler(self._membuf)
        elif self._flags & const.MMAP_CACHE:
            with open(self._fname,'r') as fn:
                self._file = mmap.mmap(fn.fileno(), 0, access=mmap.ACCESS_READ)



