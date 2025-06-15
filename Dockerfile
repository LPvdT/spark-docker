# Build stage: spark-base
FROM python:3.12.9-bookworm AS spark-base

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo curl unzip rsync default-jre build-essential \
    software-properties-common ssh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ENV variables
ENV SPARK_VERSION=4.0.0 \
    SPARK_HOME="/opt/spark" \
    HADOOP_HOME="/opt/hadoop" \
    SPARK_MASTER_PORT=7077 \
    SPARK_MASTER_HOST=spark-master \
    SPARK_MASTER="spark://spark-master:7077" \
    PYTHONPATH="/opt/spark/python/" \
    PYSPARK_PYTHON=python3 \
    IJAVA_CLASSPATH="/opt/spark/jars/*" \
    PATH="$PATH:/opt/spark/bin:/opt/spark/sbin"

# Create directories
RUN mkdir -p ${HADOOP_HOME} ${SPARK_HOME}
WORKDIR ${SPARK_HOME}

# Download and extract Spark
RUN curl -fsSL https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz -o spark.tgz && \
    tar -xvzf spark.tgz --strip-components 1 && \
    rm spark.tgz

# Make Spark binaries executable
RUN chmod +x ${SPARK_HOME}/sbin/* ${SPARK_HOME}/bin/*

# Copy Spark configuration
COPY conf/spark-defaults.conf "${SPARK_HOME}/conf/"


# Build stage: pyspark
FROM spark-base AS pyspark

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
    curl https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/4.0.0/delta-spark_2.12-4.0.0.jar \
    -Lo /opt/spark/jars/delta-spark_2.12-4.0.0.jar && \
    curl https://repo1.maven.org/maven2/io/delta/delta-storage/4.0.0/delta-storage-4.0.0.jar \
    -Lo /opt/spark/jars/delta-storage-4.0.0.jar && \
    # Download hudi jars
    curl https://repo1.maven.org/maven2/org/apache/hudi/hudi-spark3-bundle_2.12/1.0.2/hudi-spark3-bundle_2.12-1.0.2.jar \
    -Lo /opt/spark/jars/hudi-spark3-bundle_2.12-1.0.2.jar

# Copy and make entrypoint script executable
COPY --chmod=755 entrypoint.sh /opt/spark/entrypoint.sh


# # OPTIONAL Build stage: pyspark-jupyter
# FROM pyspark-runner AS pyspark-jupyter
# RUN pip3 install notebook
# ENV JUPYTER_PORT=8889
# ENV PYSPARK_DRIVER_PYTHON=jupyter \
#     PYSPARK_DRIVER_PYTHON_OPTS="notebook --no-browser --allow-root --ip=0.0.0.0 --port=${JUPYTER_PORT}"

# Entrypoint and default command
ENTRYPOINT ["/opt/spark/entrypoint.sh"]
CMD ["bash"]
