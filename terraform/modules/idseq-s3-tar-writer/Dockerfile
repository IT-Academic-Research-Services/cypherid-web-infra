FROM python:3.7-slim-bookworm

RUN mkdir -p /app
WORKDIR /app

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY s3_tar_writer/s3_tar_writer.py ./
