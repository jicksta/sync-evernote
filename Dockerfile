FROM python:2

RUN pip install evernote pyaml

RUN mkdir /chunks /worker
VOLUME /chunks
WORKDIR /worker

COPY . .

CMD python synchronizer.py
