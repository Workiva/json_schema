FROM google/dart:1.24.3 as build

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
