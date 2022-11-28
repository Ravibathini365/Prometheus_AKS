FROM vscojfrogrhel.vsazure.com/rhel-ubi-images/ubi8:latest

## Define some args that get passed at build time.
##
ARG TIME_STAMP

## Security Team Requirements
##
# start code here

## Infra Team Tuneables
##
# Point the rhel ubi public repos to artifactory's proxied repos
RUN sed -i 's/https\:\/\/cdn-ubi\.redhat\.com\/content\/public\/ubi/https\:\/\/vscojfrogrhel\.vsazure\.com\/artifactory\/rhel-ubi-base/g' /etc/yum.repos.d/ubi.repo

# Copy to image more repos to be included.
COPY ./rhel_8_repos/*.repo /etc/yum.repos.d/

# Make sure packages are up-to-date, patch system
# Add timestamp file for extra image tagging
RUN touch /tmp/${TIME_STAMP} && \
    yum --disableplugin=subscription-manager update -y

RUN yum --disableplugin=subscription-manager install iputils bind-utils telnet -y --nobest

COPY prometheus-2.32.1.linux-amd64/prometheus        /bin/prometheus
COPY prometheus-2.32.1.linux-amd64/promtool          /bin/promtool
COPY ./prometheus.yml  /etc/prometheus/prometheus.yml
COPY ./rules /etc/prometheus/rules
COPY prometheus-2.32.1.linux-amd64/console_libraries/                     /usr/share/prometheus/console_libraries/
COPY prometheus-2.32.1.linux-amd64/consoles/                              /usr/share/prometheus/consoles/
COPY prometheus-2.32.1.linux-amd64/LICENSE                                /LICENSE
COPY prometheus-2.32.1.linux-amd64/NOTICE                                 /NOTICE

RUN ln -s /usr/share/prometheus/console_libraries /usr/share/prometheus/consoles/ /etc/prometheus/
RUN mkdir -p /prometheus && \
    chown -R root:root etc/prometheus /prometheus

USER       root
EXPOSE     9090
VOLUME     [ "/prometheus" ]
WORKDIR    /prometheus
ENTRYPOINT [ "/bin/prometheus" ]
CMD        [ "--config.file=/etc/prometheus/prometheus.yml", \
             "--log.level=debug", \
             "--storage.tsdb.path=/prometheus", \
             "--storage.tsdb.retention.size=4TB", \
             "--storage.tsdb.retention.time=365d", \
             "--storage.tsdb.wal-compression", \
             "--storage.tsdb.allow-overlapping-blocks", \
             "--web.console.libraries=/usr/share/prometheus/console_libraries", \
             "--web.console.templates=/usr/share/prometheus/consoles" ]
             #"--web.external-url=http://etoprometheusnp.etocore.eastus2.vsazure.com:9090" ]
