FROM arm64v8/ubuntu:18.04

# ARG CONDA_VERSION=py37_4.8.2
# ARG PYTHON_VERSION=3.7

# ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
# ENV PATH /opt/conda/bin:$PATH

# update the OS
RUN apt-get upgrade && apt-get update && apt-get install -y  \
        build-essential \
        unzip \
        pkg-config \
        bzip2 \
        ca-certificates \
        libjpeg-dev libpng-dev libtiff-dev \
        libavcodec-dev libavformat-dev libswscale-dev \
        libv4l-dev libxvidcore-dev libx264-dev \
        libgtk-3-dev \
        libatlas-base-dev gfortran \
        curl \
        libglib2.0-0 \
        libsm6 \
        libssl-dev \
        libffi-dev \
        libxext6 \
        libxrender1 \
        vim \
        wget \
        protobuf-compiler \
        cmake \
        python3-dev \
   && rm -rf /var/lib/apt/lists/*

# download opencv
RUN  wget -O opencv.zip https://github.com/opencv/opencv/archive/4.2.0.zip && unzip opencv.zip && mv opencv-4.2.0 opencv
RUN wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.2.0.zip && unzip opencv_contrib.zip && mv opencv_contrib-4.2.0 opencv_contrib

# copy requirements
COPY requirements.txt /tmp/

# add python requirements
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN pip install -r /tmp/requirements.txt

# build opencv
RUN cd /opencv && mkdir build && cd build && \
   cmake -D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=/usr/local \
	-D INSTALL_PYTHON_EXAMPLES=OFF \
	-D INSTALL_C_EXAMPLES=OFF \
	-D OPENCV_ENABLE_NONFREE=ON \
	-D WITH_CUDA=OFF \
	-D WITH_CUDNN=OFF \
	-D OPENCV_DNN_CUDA=OFF \
	-D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
	-D HAVE_opencv_python3=ON \
        -D PYTHON_DEFAULT_EXECUTABLE=$(which python3) \
	-D PYTHON_EXECUTABLE=$(which python3) \
        -D BUILD_TESTS=OFF \
        -D BUILD_PERF_TESTS=OFF \
        -D BUILD_opencv_python_tests=OFF \
	-D BUILD_EXAMPLES=OFF ..

RUN cd /opencv/build && make -j $(nproc) && make install && ldconfig      
