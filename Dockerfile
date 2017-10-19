FROM alpine:latest
ADD ./setupRoot.sh /setupRoot.sh
RUN /setupRoot.sh && rm /setupRoot.sh
USER james
ADD ./setupUser.sh /setupUser.sh
RUN ./setupUser.sh && rm /setupUser.sh
