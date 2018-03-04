FROM debian:jessie
MAINTAINER robert@fearthecow.net

# Disable being asked stupid questions
ENV DEBIAN_FRONTEND noninteractive

# Install pre-requisites
RUN apt-get update
RUN apt-get install -yq curl git wget vim build-essential libapache2-mod-perl2 libcgi-pm-perl libdbi-perl libdbd-sqlite3-perl libdbd-sqlite3 sqlite3 apache2

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
RUN cpanm Date::Calc
RUN cpanm Date::Format
RUN cpanm Date::Parse
RUN cpanm URL::Encode
RUN cpanm Crypt::Blowfish

# Add apache config
RUN rm /etc/apache2/sites-enabled/000-default.conf
RUN a2enmod rewrite
ADD apache.conf /etc/apache2/sites-enabled/calendar.conf
ADD start_apache2.sh /
RUN chmod 755 /start_apache2.sh

# Install code
ADD src /opt/mbbscalendar/

# Allow writing to tmp folder
RUN chmod 777 /opt/mbbscalendar/ics

# Initialise DB
ADD sqlite3_db.sql /
RUN mkdir /opt/mbbscalendar/db/
RUN chmod 777 /opt/mbbscalendar/db
RUN sqlite3 /opt/mbbscalendar/db/mbbscalendar.sqlite < /sqlite3_db.sql
RUN chmod 666 /opt/mbbscalendar/db/mbbscalendar.sqlite


EXPOSE 80

CMD ["/start_apache2.sh"]

