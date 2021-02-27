import os, logging, time
import cv2
from queue import Queue, Full, Empty
import threading

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

class VideoStream:
  default_fps = 30.

  def __init__(self, stream_source, interval=0.5):
    '''
    Parameters:
      stream_source: RTSP, camera index, or video file name
      self.interval: how long to wait before next frame is served (sec)
    '''

    if stream_source == "":
      raise ValueError("stream cannot be empty")
    if interval <= 0 or interval >= 24 * 3600:
      raise ValueError("pulse interval should be positive, shorter than a day")

    self.keep_listeing_for_frames = True
    self.frame_queue = Queue(100)
    self.cam = stream_source
    self.interval = interval 
    self.frame_grabber = None
    self.is_rtsp = self.cam.lower().startswith('rtsp')

    # fix if the source is local device like /dev/video0 
    if(stream_source.isdigit()):
      self.cam = int(stream_source)

    self.fps = None
    self.delay_frames = None
    self.delay_time = None
    self.video_capture = None

  def stop(self):
    
    self.keep_listeing_for_frames = False
    if self.frame_grabber is None:
      return

    try:
      if self.frame_grabber.is_alive():
        self.frame_grabber.join(1)
      self.frame_grabber = None
      logging.info("Stopped grabbing frames")
    except:
      logging.critical("Error while stopping thread")

  def reset(self, stream_source, interval):
    '''
    Any change to stream source or interval will re-set streaming
    '''
    
    if stream_source == "":
      raise ValueError("stream cannot be empty")
    if interval <= 0 or interval >= 24 * 3600:
      raise ValueError("pulse interval should be positive, shorter than a day")

    self.stop()

    self.cam = stream_source
    self.interval = interval 

    self.start()

  def start(self):
    if self.frame_grabber is not None:
      self.stop()

    self.keep_listeing_for_frames = True
    self.frame_grabber = threading.Thread(target=self.stream_video)
    self.frame_grabber.daemon = True
    self.frame_grabber.start()
    logging.info(f"Started listening for {self.cam}")

  def get_frame_with_id(self):
    '''
    Retrieves the frame together with its frame id
    '''
    try:
      frame_and_id = self.frame_queue.get_nowait()
    except Empty:
      frame_and_id = (-1, None)
    
    return frame_and_id

  def setup_stream(self):

    self.video_capture = cv2.VideoCapture(self.cam)

    # retrieve camera properties. 
    # self.fps may not always be available
    # TODO: Need to support frame counting for RTSP!
    self.fps = self.video_capture.get(cv2.CAP_PROP_FPS)
    
    if self.fps is not None and self.fps > 0:
      self.delay_frames = int(round(self.interval * self.fps))
      logging.info(f"Retrieved FPS: {self.fps}")
    else:
      self.delay_time = self.interval

  def stream_video(self):

    repeat = 3
    wait = 0.1
    frame = None

    cur_frame = 0
    # this is used for frame delays if the video is on an infinite loop
    continuous_frame = 0

    # will create a new video capture and determine streaming speed
    self.setup_stream()

    while self.keep_listeing_for_frames:
      start_time = time.time()

      for _ in range(repeat):
        try:
            res, frame = self.video_capture.read()

            if not res:
              self.video_capture = cv2.VideoCapture(self.cam)
              res, frame = self.video_capture.read()
              cur_frame = 0
              continuous_frame = 0
            break
        except:
            # try to re-capture the stream
            logging.info("Could not capture video. Recapturing and retrying...")
            time.sleep(wait)

      if frame is None:
        logging.info("Failed to capture frame, sending blank image")
        continue

      # if we don't know how many frames we should be skipping
      # we defer to 
      if self.delay_frames is None and not self.is_rtsp:
        cur_delay = self.delay_time - time.time() + start_time
        if cur_delay > 0:
          time.sleep(cur_delay)

      # we are reading from a file, simulate 30 self.fps streaming
      # delay appropriately before enqueueing
      cur_frame += 1

      continuous_frame += 1
      if self.delay_frames is not None and (continuous_frame - 1) % self.delay_frames != 0:
        continue

      self.frame_queue.put((cur_frame, frame))

    self.video_capture.release()
    self.video_capture = None

