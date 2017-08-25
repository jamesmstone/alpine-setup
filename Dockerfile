FROM alpine:latest
ADD ./setup.sh /setup.sh
RUN /setup.sh && rm setup.sh
