#!/bin/sh
# Configure module
set -e

SCRIPT_DIR=$(dirname $0)
ARTIFACTS_DIR=${SCRIPT_DIR}/artifacts

chown -R jboss:root $SCRIPT_DIR
chmod -R ug+rwX $SCRIPT_DIR
chmod ug+x ${ARTIFACTS_DIR}/opt/jboss/container/wildfly/s2i/*

pushd ${ARTIFACTS_DIR}
cp -pr * /
popd

ln -s /opt/jboss/container/wildfly/s2i/install-common/install-common.sh /usr/local/s2i/install-common.sh
chown -h jboss:root /usr/local/s2i/install-common.sh

mkdir $WILDFLY_S2I_OUTPUT_DIR && chown -R jboss:root $WILDFLY_S2I_OUTPUT_DIR && chmod -R ug+rwX $WILDFLY_S2I_OUTPUT_DIR

# In order for applications to benefit from Galleon already downloaded artifacts
galleon_profile="<profile>\n\
      <id>local-galleon-repository</id>\n\
      <activation><activeByDefault>true</activeByDefault></activation>\n\
      <repositories>\n\
        <repository>\n\
          <id>local-galleon-repository</id>\n\
          <url>file://$GALLEON_LOCAL_MAVEN_REPO</url>\n\
          <releases>\n\
            <enabled>true</enabled>\n\
          </releases>\n\
          <snapshots>\n\
            <enabled>false</enabled>\n\
          </snapshots>\n\
        </repository>\n\
      </repositories>\n\
      <pluginRepositories>\n\
        <pluginRepository>\n\
          <id>local-galleon-plugin-repository</id>\n\
          <url>file://$GALLEON_LOCAL_MAVEN_REPO</url>\n\
          <releases>\n\
            <enabled>true</enabled>\n\
          </releases>\n\
          <snapshots>\n\
            <enabled>false</enabled>\n\
          </snapshots>\n\
        </pluginRepository>\n\
      </pluginRepositories>\n\
    </profile>\n\
"
sed -i "s|<\!-- ### configured profiles ### -->|$galleon_profile <\!-- ### configured profiles ### -->|" $HOME/.m2/settings.xml

# Copy settings.xml to a safe location that will be set at assembly time.
cp $HOME/.m2/settings.xml $HOME/.m2/settings-s2i.xml
chown jboss:root $HOME/.m2/settings-s2i.xml
chmod ug+rwX $HOME/.m2/settings-s2i.xml
