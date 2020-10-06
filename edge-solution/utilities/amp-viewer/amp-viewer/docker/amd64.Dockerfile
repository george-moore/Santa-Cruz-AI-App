FROM amd64/node:13-slim
ENV WORKINGDIR /app
WORKDIR ${WORKINGDIR}

ADD package.json ${WORKINGDIR}/package.json
ADD tslint.json ${WORKINGDIR}/tslint.json
ADD tsconfig.json ${WORKINGDIR}/tsconfig.json
ADD src ${WORKINGDIR}/src
ADD static ${WORKINGDIR}/static
ADD client_dist ${WORKINGDIR}/client_dist

RUN npm install -q && \
    ./node_modules/.bin/tsc -p . && \
    ./node_modules/.bin/tslint -p . && \
    npm prune --production && \
    rm -f tslint.json && \
    rm -f tsconfig.json && \
    rm -rf src

EXPOSE 8094

ENTRYPOINT ["node", "./dist/index"]
