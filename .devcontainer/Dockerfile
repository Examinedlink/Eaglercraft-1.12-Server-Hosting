FROM qwedfrnhgef/codespaces:latest

COPY --from=eclipse-temurin:17-jdk /opt/java/openjdk /opt/java/openjdk

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

COPY . /workspaces/
