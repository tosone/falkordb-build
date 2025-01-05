FROM buildpack-deps:stable AS compiler

COPY ./0001-fix-typo.patch .
COPY ./0002-add-log.patch .
COPY ./0003-add-more-log.patch .
COPY ./0001-update.patch .

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
    build-essential cmake m4 automake peg libtool autoconf python3 python3-pip \
	; \
	rm -rf /var/lib/apt/lists/* && \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
  . $HOME/.cargo/env && \
  git clone --recurse-submodules -j8 https://github.com/FalkorDB/FalkorDB.git falkordb && \
  cd falkordb && patch -p1 < /0001-fix-typo.patch && patch -p1 < /0002-add-log.patch && \
  patch -p1 < /0003-add-more-log.patch && \
  cd deps/RediSearch && patch -p1 < /0001-update.patch && cd ../.. && \
  make

FROM redis:7.2.6

RUN apt-get update && apt-get install -y libgomp1 nodejs && rm -rf /var/lib/apt/lists/*

WORKDIR /FalkorDB

COPY --from=compiler /falkordb/build/docker/run.sh /FalkorDB/build/docker/run.sh
COPY --from=compiler /falkordb/build/docker/gen-certs.sh /FalkorDB/build/docker/gen-certs.sh
COPY --from=compiler /falkordb/bin/linux*/src/falkordb.so /FalkorDB/bin/src/falkordb.so

ENV TLS=0
ENV FALKORDB_ARGS="MAX_QUEUED_QUERIES 25 TIMEOUT 1000 RESULTSET_SIZE 10000"

CMD ["/FalkorDB/build/docker/run.sh"]
