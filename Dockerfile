FROM alpine:3.13.0

RUN mkdir /var/task/ \
    && apk add perl perl-net-ssleay perl-app-cpanminus perl-dev build-base wget libressl-dev musl-dev expat-dev \
    && cpanm install --notest --no-man-pages AWS::Lambda Email::MIME Text::Xslate Paws \
    && rm -Rf /root/.cpanm/ \
    && find /usr/local/share/perl5/ | grep '\.pod$' | xargs rm \
    && apk del perl-app-cpanminus perl-dev build-base wget libressl-dev musl-dev

RUN apk add perl-test-longstring perl-yaml

COPY lib /var/task/lib/
COPY handler.pl /var/task/
WORKDIR /var/task/
ENTRYPOINT [ "/usr/bin/perl", "-Ilib", "-MAWS::Lambda::Bootstrap", "-e", "bootstrap(@ARGV)" ]
CMD [ "handler.handle" ]
