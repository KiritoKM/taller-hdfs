FROM eclipse-temurin:11-jre-jammy

# Las primeras capas son idénticas al Dockerfile del repositorio de ejemplo
# (CloudComputingUAO/HDFS), así Docker reutiliza la capa con Hadoop ya descargado.
ARG HADOOP_VERSION=3.4.1
ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/hadoop/bin:/opt/hadoop/sbin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates bash procps \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fSL --retry 3 "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" -o /tmp/hadoop.tar.gz \
    && mkdir -p /opt/hadoop \
    && tar -xzf /tmp/hadoop.tar.gz -C /opt/hadoop --strip-components=1 \
    && rm /tmp/hadoop.tar.gz \
    && mkdir -p /data/name /data/data

# Python 3 para los jobs de Hadoop Streaming (mappers/reducers en Python).
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data/yarn/local /data/yarn/logs

ENV HADOOP_MAPRED_HOME=/opt/hadoop \
    HADOOP_YARN_HOME=/opt/hadoop \
    HADOOP_STREAMING_JAR=/opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-3.4.1.jar \
    HADOOP_EXAMPLES_JAR=/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.1.jar

COPY config/core-site.xml config/hdfs-site.xml config/yarn-site.xml config/mapred-site.xml /opt/hadoop/etc/hadoop/
COPY scripts/entrypoint.sh /usr/local/bin/hadoop-lab-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/hadoop-lab-entrypoint && chmod +x /usr/local/bin/hadoop-lab-entrypoint

ENTRYPOINT ["/usr/local/bin/hadoop-lab-entrypoint"]
