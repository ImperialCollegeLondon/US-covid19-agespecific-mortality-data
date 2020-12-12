FROM python:3.7
# set the working directory in the container check
WORKDIR /code
COPY requirements.txt .
RUN apt-get update
RUN apt-get install -y libgdal-dev
RUN apt-get install -y libwww-perl
RUN export CPLUS_INCLUDE_PATH=/usr/include/gdal
RUN apt-get install -y chromium
RUN export C_INCLUDE_PATH=/usr/include/gdal
RUN pip install --user -r requirements.txt
RUN pip install Fiona
RUN pip install wheel
