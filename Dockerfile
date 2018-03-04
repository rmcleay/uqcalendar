FROM debian:jessie
MAINTAINER robert@fearthecow.net

# Disable being asked stupid questions
ENV DEBIAN_FRONTEND noninteractive

# Install pre-requisites
RUN apt-get update
RUN apt-get install -yq curl git wget vim build-essential libapache2-mod-perl2 libcgi-pm-perl libdbi-perl libdbd-sqlite3-perl libdbd-sqlite3

# install CPAN minus
RUN curl -L http://cpanmin.us | perl - --self-upgrade

# install required perl modules
RUN cpanm Crypt::CBC
RUN cpanm Crypt::SaltedHash
RUN cpanm MIME::Base64::URLSafe
RUN cpanm WWW::Mechanize
RUN cpanm Apache2::Access
RUN cpanm Apache2::Connection
RUN cpanm Apache2::RequestRec

# Install code
ADD src /opt/mbbscalendar/

# Initialise DB
RUN apt-get install -yq sqlite3
ADD sqlite3_db.sql /
RUN sqlite3 /opt/mbbscalendar/mbbscalendar.sqlite < /sqlite3_db.sql

# Add apache config
ADD apache.conf /etc/apache2/conf.d/calendar.conf

EXPOSE 80

CMD ["httpd -DFOREGROUND"]

