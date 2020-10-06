import tempfile
import mmap
import os
import logging

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)
# ***********************************************************************************
# Shared memory management 
#
class SharedMemoryManager:
    def __init__(self, name, size):
        try:
            self._shmFilePath = '/dev/shm'
            self._shmFileName = name

            self._shmFileSize = size

            self._shmFileFullPath = os.path.join(self._shmFilePath, self._shmFileName)

            self._shmFile = open(self._shmFileFullPath, 'r+b')            
            self._shm = mmap.mmap(self._shmFile.fileno(), self._shmFileSize)

            self._memSlots = dict()

            logging.info('Shared memory name: {0}'.format(self._shmFileFullPath))
        except Exception as e:
            logging.error(e)
            raise

    def ReadBytes(self, memorySlotOffset, memorySlotLength):
        try:
            # This is Non-Zero Copy operation
            # self._shm.seek(memorySlotOffset, os.SEEK_SET)
            # bytesRead = self._shm.read(memorySlotLength)
            # return bytesRead

            #Zero-copy version
            return memoryview(self._shm)[memorySlotOffset:memorySlotOffset+memorySlotLength]

        except Exception as e:
            logging.error(e)
            raise

    def __del__(self):
        try:            
            self._shmFile.close()
        except Exception as e:
            logging.error(e)
            raise
