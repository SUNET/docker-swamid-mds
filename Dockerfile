FROM ubuntu
MAINTAINER leifj@sunet.se
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get -q update
RUN apt-get -y upgrade
RUN apt-get -y install apache2 ssl-cert
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod expires
RUN rm -f /etc/apache2/sites-available/*
RUN rm -f /etc/apache2/sites-enabled/*
RUN rm -rf /var/www/*
COPY /apache2.conf /etc/apache2/
ADD start.sh /start.sh
RUN chmod a+rx /start.sh
ENV PUBLIC_HOSTNAME md.swamid.se
EXPOSE 443
EXPOSE 80
ENTRYPOINT ["/start.sh"]
