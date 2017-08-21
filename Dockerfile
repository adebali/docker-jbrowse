# JBrowse
# VERSION 1.0
FROM nginx
MAINTAINER Eric Rasche <esr@tamu.edu>
ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /usr/share/man/man1 /usr/share/man/man7

RUN apt-get -qq update --fix-missing
RUN apt-get --no-install-recommends -y install git build-essential zlib1g-dev libxml2-dev libexpat-dev postgresql-client libpq-dev libpng-dev wget unzip perl-doc

# JBrowse releases are only minified on jbrowse.org
RUN wget -O jbrowse.zip http://jbrowse.org/wordpress/wp-content/plugins/download-monitor/download.php?id=109 && \
    unzip jbrowse.zip && \
    mv JBrowse-* jbrowse

WORKDIR /jbrowse/
RUN mkdir -p /jbrowse/custom_scripts
RUN ./setup.sh && \
    ./bin/cpanm --notest --force JSON Digest::Crc32 Hash::Merge PerlIO::gzip Devel::Size \
    Heap::Simple Heap::Simple::XS List::MoreUtils Exception::Class Test::Warn Bio::Perl \
    Bio::DB::SeqFeature::Store File::Next Bio::DB::Das::Chado Bio::FeatureIO Bio::GFF3::LowLevel::Parser \
    DBD::SQLite File::Copy::Recursive JSON::XS Parse::RecDescent local::lib Digest::Crc32 Bio::GFF3::LowLevel::Parser && \
    rm -rf /root/.cpan/

RUN perl Makefile.PL && make && make install
RUN rm -rf /usr/share/nginx/html && ln -s /jbrowse/ /usr/share/nginx/html

RUN echo "include += data/datasets.conf" >> /jbrowse/jbrowse.conf

VOLUME /data
COPY docker-entrypoint.sh /
CMD ["/docker-entrypoint.sh"]
