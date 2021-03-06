FROM docker.elastic.co/kibana/kibana-oss:7.6.2

# Copyright (c) 2020 Battelle Energy Alliance, LLC.  All rights reserved.
LABEL maintainer="malcolm.netsec@gmail.com"
LABEL org.opencontainers.image.authors='malcolm.netsec@gmail.com'
LABEL org.opencontainers.image.url='https://github.com/idaholab/Malcolm'
LABEL org.opencontainers.image.documentation='https://github.com/idaholab/Malcolm/blob/master/README.md'
LABEL org.opencontainers.image.source='https://github.com/idaholab/Malcolm'
LABEL org.opencontainers.image.vendor='Idaho National Laboratory'
LABEL org.opencontainers.image.title='malcolmnetsec/kibana-oss'
LABEL org.opencontainers.image.description='Malcolm container providing Kibana (the Apache-licensed variant)'


ARG ELASTICSEARCH_URL="http://elasticsearch:9200"
ARG CREATE_ES_MOLOCH_SESSION_INDEX="true"
ARG MOLOCH_INDEX_PATTERN="sessions2-*"
ARG MOLOCH_INDEX_PATTERN_ID="sessions2-*"
ARG MOLOCH_INDEX_TIME_FIELD="firstPacket"
ARG KIBANA_DEFAULT_DASHBOARD="0ad3d7c2-3441-485e-9dfe-dbb22e84e576"
ARG KIBANA_OFFLINE_REGION_MAPS="false"
ARG KIBANA_OFFLINE_REGION_MAPS_PORT="28991"

ENV CREATE_ES_MOLOCH_SESSION_INDEX $CREATE_ES_MOLOCH_SESSION_INDEX
ENV MOLOCH_INDEX_PATTERN $MOLOCH_INDEX_PATTERN
ENV MOLOCH_INDEX_PATTERN_ID $MOLOCH_INDEX_PATTERN_ID
ENV MOLOCH_INDEX_TIME_FIELD $MOLOCH_INDEX_TIME_FIELD
ENV KIBANA_DEFAULT_DASHBOARD $KIBANA_DEFAULT_DASHBOARD
ENV KIBANA_OFFLINE_REGION_MAPS $KIBANA_OFFLINE_REGION_MAPS
ENV KIBANA_OFFLINE_REGION_MAPS_PORT $KIBANA_OFFLINE_REGION_MAPS_PORT
ENV PATH="/data:${PATH}"
ENV ELASTICSEARCH_URL $ELASTICSEARCH_URL

USER root

RUN yum install -y epel-release && \
    yum update -y && \
    yum install -y curl cronie inotify-tools npm psmisc python-requests python-setuptools zip unzip && \
    yum clean all && \
    easy_install supervisor && \
    npm install -g http-server

ADD kibana/scripts /data/
ADD shared/bin/elastic_search_status.sh /data/
ADD shared/bin/cron_env_centos.sh /data/
ADD kibana/kibana-standard.yml /opt/kibana/config/kibana-standard.yml
ADD kibana/kibana-offline-maps.yml /opt/kibana/config/kibana-offline-maps.yml
ADD kibana/supervisord.conf /etc/supervisord.conf
ADD kibana/dashboards /opt/kibana/dashboards
ADD kibana/maps /opt/maps
ADD kibana/elastalert-kibana-plugin/server/routes/elastalert.js /tmp/elastalert-server-routes.js

# todo: these extra plugins are kind of gutted right now with 7.x, need to fix

# see https://github.com/walterra/kibana-milestones-vis/issues/9
# curl -sSL -o /tmp/kibana-milestones.zip "https://github.com/walterra/kibana-milestones-vis/releases/download/v7.1.1/kibana-milestones-vis-7.1.1.zip"
#    cd /tmp && \
#    echo "Installing Milestones visualization..." && \
#      unzip kibana-milestones.zip kibana/kibana-milestones-vis/package.json && \
#      sed -i "s/7\.1\.1/7\.6\.2/g" kibana/kibana-milestones-vis/package.json && \
#      zip kibana-milestones.zip kibana/kibana-milestones-vis/package.json && \
#      cd /usr/share/kibana/plugins && \
#      /usr/share/kibana/bin/kibana-plugin install file:///tmp/kibana-milestones.zip --allow-root && \
#      rm -rf /tmp/kibana-milestones.zip /tmp/kibana

# not optimizing in 6.6+ correctly
# curl -sSL -o /tmp/kibana-calendar.zip "https://github.com/aaronoah/kibana_calendar_vis/releases/download/v6.4.0/kibana_calendar_vis-6.4.0.zip"
#    echo "Installing Calendar visualization..." && \
#    unzip kibana-calendar.zip kibana/kibana_calendar_vis/package.json && \
#    sed -i "s/6\.4\.0/6\.6\.0/g" kibana/kibana_calendar_vis/package.json && \
#    zip kibana-calendar.zip kibana/kibana_calendar_vis/package.json && \
#    /usr/share/kibana/bin/kibana-plugin install file:///tmp/kibana-calendar.zip --allow-root && \
#    rm -rf /tmp/kibana-calendar.zip /tmp/kibana && \

RUN curl -sSL -o /tmp/kibana-comments.zip "https://github.com/gwintzer/kibana-comments-app-plugin/releases/download/7.4.0/kibana-comments-app-plugin-7.4.0-latest.zip" && \
      curl -sSL -o /tmp/kibana-swimlane.zip "https://github.com/prelert/kibana-swimlane-vis/releases/download/v7.6.2/prelert_swimlane_vis-7.6.2.zip" && \
      curl -sSL -o /tmp/elastalert-kibana-plugin.zip "https://github.com/bitsensor/elastalert-kibana-plugin/releases/download/1.1.0/elastalert-kibana-plugin-1.1.0-7.5.0.zip" && \
    chmod 755 /data/*.sh /data/*.py && \
    chown -R kibana:kibana /opt/kibana/dashboards /opt/maps /opt/kibana/config/kibana*.yml && \
    chmod 400 /opt/maps/* && \
    mkdir -p /var/log/supervisor && \
    (echo -e "*/2 * * * * su -c /data/kibana-create-moloch-sessions-index.sh kibana >/dev/null 2>&1\n0 * * * * su -c /data/kibana_index_refresh.py kibana >/dev/null 2>&1\n" | crontab -) && \
    cd /tmp && \
    echo "Installing ElastAlert plugin..." && \
      unzip elastalert-kibana-plugin.zip kibana/elastalert-kibana-plugin/package.json kibana/elastalert-kibana-plugin/public/components/main/main.js && \
      sed -i "s/7\.5\.0/7\.6\.2/g" kibana/elastalert-kibana-plugin/package.json && \
      sed -i "s/^import.*eui_theme_light.css.*$//" kibana/elastalert-kibana-plugin/public/components/main/main.js && \
      mkdir -p kibana/elastalert-kibana-plugin/server/routes/ && \
      cp /tmp/elastalert-server-routes.js kibana/elastalert-kibana-plugin/server/routes/elastalert.js && \
      zip elastalert-kibana-plugin.zip \
          kibana/elastalert-kibana-plugin/package.json \
          kibana/elastalert-kibana-plugin/public/components/main/main.js \
          kibana/elastalert-kibana-plugin/server/routes/elastalert.js && \
      cd /usr/share/kibana/plugins && \
      /usr/share/kibana/bin/kibana-plugin install file:///tmp/elastalert-kibana-plugin.zip --allow-root && \
      rm -rf /tmp/elastalert-kibana-plugin.zip /tmp/elastalert.js /tmp/kibana && \
    cd /tmp && \
    echo "Installing Comments visualization..." && \
      unzip kibana-comments.zip kibana/kibana-comments-app-plugin/package.json && \
      sed -i "s/7\.4\.0/7\.6\.2/g" kibana/kibana-comments-app-plugin/package.json && \
      zip kibana-comments.zip kibana/kibana-comments-app-plugin/package.json && \
      cd /usr/share/kibana/plugins && \
      /usr/share/kibana/bin/kibana-plugin install file:///tmp/kibana-comments.zip --allow-root && \
      rm -rf /tmp/kibana-comments.zip /tmp/kibana && \
    cd /tmp && \
    echo "Installing Swimlanes visualization..." && \
      unzip kibana-swimlane.zip kibana/prelert_swimlane_vis/package.json && \
      sed -i "s/7\.6\.2/7\.6\.2/g" kibana/prelert_swimlane_vis/package.json && \
      zip kibana-swimlane.zip kibana/prelert_swimlane_vis/package.json && \
      cd /usr/share/kibana/plugins && \
      /usr/share/kibana/bin/kibana-plugin install file:///tmp/kibana-swimlane.zip --allow-root && \
      bash -c "find /usr/share/kibana/plugins/prelert_swimlane_vis/ -type f -exec chmod 644 '{}' \;" && \
      rm -rf /tmp/kibana-swimlane.zip /tmp/kibana

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-u", "root", "-n"]


# to be populated at build-time:
ARG BUILD_DATE
ARG MALCOLM_VERSION
ARG VCS_REVISION

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.version=$MALCOLM_VERSION
LABEL org.opencontainers.image.revision=$VCS_REVISION
