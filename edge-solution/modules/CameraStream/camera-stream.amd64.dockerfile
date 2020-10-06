ARG ACR_NAME
ARG IMAGE_BASE

FROM  ${ACR_NAME}/${IMAGE_BASE}_base:latest-amd64

COPY ./camera-stream /camera-stream
RUN /bin/bash -c "chmod +x /camera-stream/run_camera.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["/camera-stream/run_camera.sh camera.py"]
