FROM java:8-jdk
# Use bash instead of default /bin/sh
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install build tools for ruby and puppet
RUN apt-get update
RUN apt-get install -y apt-utils
RUN apt-get install -y ruby git-core git zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev wget curl vim
RUN rm -rf /var/lib/apt/lists/*

# Use git to install rbenv and setup the environment
RUN git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
RUN echo 'export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"' >> ~/.bashrc

# Install ruby-build for installing different ruby versions
RUN git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
RUN echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
RUN echo 'export PATH="$HOME/.rbenv/versions/1.8.7-p352/bin:$PATH"' >> ~/.bashrc
RUN gem update --system

# Initialize correct ruby on shell start
RUN echo 'eval "$(rbenv init -)"' >> ~/.bashrc
RUN echo 'rbenv global 1.8.7-p352' >> ~/.bashrc
RUN echo 'rbenv local 1.8.7-p352' >> ~/.bashrc
RUN echo 'rbenv shell 1.8.7-p352' >> ~/.bashrc

# Use rbenv to install ruby 1.8.7-p352, then install bundler
# These flags are mandatory when compiling old versions of ruby with a new GCC
RUN CFLAGS="-O2 -fno-tree-dce -fno-optimize-sibling-calls" ~/.rbenv/bin/rbenv install 1.8.7-p352
RUN source ~/.bashrc && gem install bundler -v 1.10.5

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ENV JENKINS_VERSION 1.625.2
ENV JENKINS_SHA 395fe6975cf75d93d9fafdafe96d9aab1996233b


# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins-ci.org

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# Use root user instead
USER root

COPY jenkins.sh /usr/local/bin/jenkins.sh

ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh

