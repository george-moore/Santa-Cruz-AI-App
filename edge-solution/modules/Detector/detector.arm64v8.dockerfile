ARG ACR_NAME
ARG IMAGE_BASE

FROM  ${ACR_NAME}/${IMAGE_BASE}_base:latest-arm64v8

COPY ./detector /detector
RUN /bin/bash -c "chmod +x ./detector/*.sh"

ENTRYPOINT [ "/bin/bash", "-c"]
CMD  ["/detector/run_detector.sh detector.py"]
