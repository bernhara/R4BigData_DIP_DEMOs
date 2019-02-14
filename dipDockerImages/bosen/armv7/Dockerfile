# -*- mode: indented-text -*-

FROM raspbian/stretch:latest

LABEL maintainer="BERNHARD Raphael <raphael.bernhard@orange.com>"

ENV http_proxy=${http_proxy}
ENV https_proxy=${https_proxy}

RUN test -z "$skip_apt" \
    && apt-get update \
    && apt-get install -y \
            libgcc1 \
            libc6 \
            libzmq5 \
            libgoogle-glog0v5 \
            libgflags2v5 \
            libconfig++9v5 \
            \
            libsnappy1v5 \
            libyaml-cpp0.5v5 \
            libleveldb1v5 \
            \
            libboost-system1.62.0 \
            libboost-thread1.62.0 \
     && apt-get clean \
     && rm -rf /tmp/* \
     && rm -f /core


#                   apt-utils \

COPY tmp_root /

CMD ["/home/dip/bin/testit.sh"]

ENV MLR_MAIN=/home/dip/bin/mlr_main GLOG_logtostderr=true GLOG_v=-1 GLOG_minloglevel=0 VERBOSE="" MLR_TIMEOUT=0
