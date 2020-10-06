#FROM mcr.microsoft.com/azureml/o16n-sample-user-base/ubuntu-miniconda
FROM ubuntu:18.04

ARG CONDA_VERSION=py37_4.8.2
ARG PYTHON_VERSION=3.7

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        vim \
        wget \
        protobuf-compiler \
        cmake \
   && rm -rf /var/lib/apt/lists/*

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    /opt/conda/bin/conda clean -tipsy

RUN /bin/bash -c conda install -y conda=${CONDA_VERSION} python=${PYTHON_VERSION} && \
    conda clean -aqy && \
    rm -rf /opt/conda/pkgs && \
    find / -type d -name __pycache__ -prune -exec rm -rf {} \;

ARG ENV_NAME=base
ARG ENV_YAML=environment.yml
ARG TMP_FOLDER=/tmp_setup

ADD ${ENV_YAML} ${TMP_FOLDER}/

RUN conda env update -f ${TMP_FOLDER}/${ENV_YAML} && \
conda clean -a -y
