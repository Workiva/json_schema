FROM google/dart:1.24.3 as build

ARG GIT_SSH_KEY
ARG KNOWN_HOSTS_CONTENT
RUN mkdir /root/.ssh/ && \
    echo "$KNOWN_HOSTS_CONTENT" > "/root/.ssh/known_hosts" && \
    chmod 700 /root/.ssh/ && \
    umask 0077 && echo "$GIT_SSH_KEY" >/root/.ssh/id_rsa && \
    eval "$(ssh-agent -s)" && ssh-add /root/.ssh/id_rsa

WORKDIR /build/
ADD . /build/

ARG BUILD_ID
ARG GIT_COMMIT
ARG GIT_BRANCH
ARG GIT_TAG
ARG GIT_COMMIT_RANGE
ARG GIT_HEAD_URL
ARG GIT_MERGE_HEAD
ARG GIT_MERGE_BRANCH

RUN pub get && \
    git config remote.origin.url "git@github.com:Workiva/semver-audit-dart.git" && \
    git clone ssh://git@github.com/workiva/semver-audit-dart.git --branch 1.4.0 && \
    git config remote.origin.url "git@github.com:Workiva/json_schema.git" && \
    pub global activate --source path ./semver-audit-dart && \
    pub global run semver_audit report --repo Workiva/json_schema
ARG BUILD_ARTIFACTS_BUILD=/build/pubspec.lock
FROM scratch
