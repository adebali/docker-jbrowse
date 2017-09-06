FROM debian:stretch-slim

MAINTAINER NGINX Docker Maintainers "docker-maint@nginx.com"

ENV NGINX_VERSION 1.13.3-1~stretch
ENV NJS_VERSION   1.13.3.0.1.11-1~stretch

RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y gnupg1 \
	&& \
	NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	apt-get remove --purge -y gnupg1 && apt-get -y --purge autoremove && rm -rf /var/lib/apt/lists/* \
	&& echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						nginx=${NGINX_VERSION} \
						nginx-module-xslt=${NGINX_VERSION} \
						nginx-module-geoip=${NGINX_VERSION} \
						nginx-module-image-filter=${NGINX_VERSION} \
						nginx-module-njs=${NJS_VERSION} \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

STOPSIGNAL SIGTERM

RUN sed -i -e 's/80/8080/g' /etc/nginx/conf.d/default.conf

ENV DEBIAN_FRONTEND noninteractive

LABEL io.k8s.description="jbrowse applcication" \
 io.k8s.display-name="JBROWSE APP" \
 io.openshift.expose-services="8080:http"

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

RUN chown -R 1001:0 /var/cache/nginx && \
    chmod -R g+w /var/cache/nginx && \
    chmod -R g+w /run

USER 1001
EXPOSE 8080

COPY docker-entrypoint.sh /
CMD ["/docker-entrypoint.sh"]
