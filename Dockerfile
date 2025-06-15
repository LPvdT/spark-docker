# Build stage: spark-base
FROM python:3.12-bookworm AS spark-base

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo curl unzip rsync default-jre build-essential \
    software-properties-common ssh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ENV variables
ENV SPARK_VERSION=3.5.6 \
    SPARK_HOME="/opt/spark" \
    HADOOP_HOME="/opt/hadoop" \
    SPARK_MASTER_PORT=7077 \
    SPARK_MASTER_HOST=spark-master \
    SPARK_MASTER="spark://spark-master:7077" \
    PYTHONPATH="/opt/spark/python/" \
    PYSPARK_PYTHON=python3 \
    IJAVA_CLASSPATH="/opt/spark/jars/*" \
    PATH="$PATH:/opt/spark/bin:/opt/spark/sbin"\
    # Add iceberg spark runtime jar to IJava classpath
    IJAVA_CLASSPATH="/opt/spark/jars/*"

# Create directories
RUN mkdir -p ${HADOOP_HOME} && mkdir -p ${SPARK_HOME}
WORKDIR ${SPARK_HOME}

# Download spark and unpack it
RUN mkdir -p ${SPARK_HOME} \
    && curl https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz -o spark-${SPARK_VERSION}-bin-hadoop3.tgz \
    && tar xvzf spark-${SPARK_VERSION}-bin-hadoop3.tgz --directory ${SPARK_HOME} --strip-components 1 \
    && rm -rf spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Add spark binaries to shell and enable execution
RUN chmod u+x /opt/spark/sbin/* && \
    chmod u+x /opt/spark/bin/*
ENV PATH="$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin"

# Add a spark config for all nodes
COPY conf/spark-defaults.conf "$SPARK_HOME/conf/"

# Build stage: pyspark
FROM spark-base AS pyspark

# Install python deps
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Build stage: pyspark-runner
FROM pyspark AS pyspark-runner

RUN mkdir -p /opt/spark/jars && \
    # Download iceberg jars
    curl https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.4_2.12/1.9.1/iceberg-spark-runtime-3.4_2.12-1.9.1.jar \
    -Lo /opt/spark/jars/iceberg-spark-runtime-3.4_2.12-1.9.1.jar && \
    curl https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-extensions-3.4_2.12/1.9.1/iceberg-spark-extensions-3.4_2.12-1.9.1.jar \
    -Lo /opt/spark/jars/iceberg-spark-extensions-3.4_2.12-1.9.1.jar && \
    # Download delta jars
    curl https://repo1.maven.org/maven2/io/delta/delta-core_2.12/2.4.0/delta-core_2.12-2.4.0.jar \
    -Lo /opt/spark/jars/delta-core_2.12-2.4.0.jar && \
    curl https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/${SPARK_VERSION}/delta-spark_2.12-${SPARK_VERSION}.jar \
    -Lo /opt/spark/jars/delta-spark_2.12-${SPARK_VERSION}.jar && \
    curl https://repo1.maven.org/maven2/io/delta/delta-storage/${SPARK_VERSION}/delta-storage-${SPARK_VERSION}.jar \
    -Lo /opt/spark/jars/delta-storage-${SPARK_VERSION}.jar && \
    # Download hudi jars
    curl https://repo1.maven.org/maven2/org/apache/hudi/hudi-spark3-bundle_2.12/1.0.2/hudi-spark3-bundle_2.12-1.0.2.jar \
    -Lo /opt/spark/jars/hudi-spark3-bundle_2.12-1.0.2.jar

COPY entrypoint.sh .
RUN chmod u+x /opt/spark/entrypoint.sh

# OPTIONAL Build stage: pyspark-jupyter
# FROM pyspark-runner AS pyspark-jupyter

# RUN pip3 install notebook

# ENV JUPYTER_PORT=8889

# ENV PYSPARK_DRIVER_PYTHON=jupyter
# ENV PYSPARK_DRIVER_PYTHON_OPTS="notebook --no-browser --allow-root --ip=0.0.0.0 --port=${JUPYTER_PORT}"
# # --ip=0.0.0.0 - listen all interfaces
# # --port=${JUPYTER_PORT} - listen ip on port 8889
# # --allow-root - to run Jupyter in this container by root user. It is adviced to change the user to non-root.

ENTRYPOINT ["./entrypoint.sh"]
CMD [ "bash" ]

# Now go to interactive shell mode
# -$ docker exec -it spark-master /bin/bash
# then execute
# -$ pyspark

# If Jupyter is installed, you will see an URL: `http://127.0.0.1:8889/?token=...`
# This will open Jupyter web UI in your host machine browser.
# Then go to /warehouse/ and test the installation.
