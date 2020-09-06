# Base image
# Install Python Image
ARG baseimage_tag='11'
FROM openjdk:${baseimage_tag}  AS compile-image

# Labels ######################################################################
LABEL maintainer="Muhammad Hasannudin Yusa"
LABEL maintainer.email="muhammad.hasannudin(at)big.go.id"
LABEL maintainer.organization="Badan Informasi Geospasial (BIG)"
LABEL source.repo="https://github.com/emhayusa/docker_4d_app"

# set up python
RUN set -x && \
	apt-get update && \
 	apt-get -y install python3

# Install dependencies
RUN set -x && \
	apt-get -y install python3-dev && \
	apt-get -y install gcc && \
	apt-get -y install libpq-dev && \
	apt-get -y install libffi-dev

# create share folder structure
RUN set -x && \
  mkdir -p /opt/code

# Create a virtual environment for all the Python dependencies
RUN set -x && \
	apt-get -y install python3-venv
	
RUN set -x && \ 
	python3 -m venv /opt/venv

# Make sure we use the virtualenv:
ENV PATH="/opt/venv/bin:$PATH"

RUN set -x && \
	pip3 install --upgrade pip

# Install and compile uwsgi
RUN set -x && \
	pip3 install uwsgi==2.0.18

# Install other dependencies
COPY requirements.txt /opt/

RUN set -x && \
	pip3 install -r /opt/requirements.txt


########
# This image is the runtime, will copy the dependencies from the other
########
FROM openjdk:${baseimage_tag}  AS runtime-image


# Install python
RUN set -x && \
	apt-get update && \
	apt-get -y install python3 && \
	apt-get -y install curl && \
	apt-get -y install libffi-dev && \
	apt-get -y install libpq-dev && \
	apt-get -y install libpython3.7-dev


# Setup PostGIS and 3DCityDB ##################################################
ARG impexp_version='master'
ENV IMPEXP_VERSION=${impexp_version}

ARG BUILD_PACKAGES='git'

# Setup build and runtime deps
RUN set -x && \
  apt-get install -y --no-install-recommends $BUILD_PACKAGES

# Clone 3DCityDB
RUN set -x && \
  mkdir -p build_tmp && \
  git clone -b "${IMPEXP_VERSION}" --depth 1 https://github.com/3dcitydb/importer-exporter.git build_tmp

# Build ImpExp
RUN set -x && \
  cd build_tmp && \
  chmod u+x ./gradlew && \
  ./gradlew installDist

# Move dist
RUN set -x && \
  ls -lA . && \
  mv /build_tmp/impexp-client/build/install/3DCityDB-Importer-Exporter/ /impexp && \
  ls -lA /impexp

# create share folder structure
RUN set -x && \
  mkdir -p /share/config /share/data

# Cleanup
RUN set -x && \
  rm -rf build_tmp && \
  ls -lA && \
  apt-get purge -y --auto-remove $BUILD_PACKAGES && \
  rm -rf /var/lib/apt/lists/*

# Copy entrypoint script
COPY impexp.sh /impexp/bin

RUN set -x && \
  chmod -v a+x /impexp/bin/* /impexp/contribs/collada2gltf/COLLADA2GLTF*linux/COLLADA2GLTF*



# Copy uWSGI configuration
RUN set -x && \
	mkdir -p /opt/uwsgi

ADD uwsgi.ini /opt/uwsgi/
ADD start_server.sh /opt/uwsgi/

# Create a user to run the service
RUN adduser uwsgi
USER uwsgi

# Copy the venv with compile dependencies from the compile-image
COPY --chown=uwsgi:uwsgi --from=compile-image /opt/venv /opt/venv

# Be sure to activate the venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy the code
COPY --chown=uwsgi:uwsgi wsgi.py /opt/code/
# Run parameters
WORKDIR /opt/code
#USER root
EXPOSE 8000
CMD ["/bin/sh", "/opt/uwsgi/start_server.sh"]