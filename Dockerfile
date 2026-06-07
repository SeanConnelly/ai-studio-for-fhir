# syntax=docker/dockerfile:1

# ── Stage 1: build the React/Vite SPA ──
FROM node:20-alpine AS frontend
WORKDIR /build
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
# The SPAs import the demo-input catalogues (ask questions / triage scenarios)
# from the repo's seed tree via relative paths; mirror that layout so the
# imports resolve inside the build stage too.
COPY seed/demo-inputs/ /seed/demo-inputs/
RUN npm run build

# ── Stage 2: IRIS for Health + IPM, with everything baked in ──
FROM intersystemsdc/irishealth-community:latest

USER root
RUN mkdir -p /home/irisowner/app /opt/seed /usr/irissys/csp/fhir-agent-studio /usr/irissys/csp/clinical
COPY iris/ /home/irisowner/app/iris/
COPY module.xml iris.script create-fast-namespace.script /home/irisowner/app/
COPY seed/ /opt/seed/
# Two built SPAs: the Studio (served by FAST.API.Portal at /fhir-agent-studio/) and
# the Clinical app (served by FAST.API.ClinicalPortal at /clinical/).
COPY --from=frontend /build/dist/studio/ /usr/irissys/csp/fhir-agent-studio/
COPY --from=frontend /build/dist/clinical/ /usr/irissys/csp/clinical/
RUN chown -R irisowner:irisowner /home/irisowner/app /opt/seed /usr/irissys/csp/fhir-agent-studio /usr/irissys/csp/clinical
USER irisowner

# Embedded Python dependency: sqlparse powers the AST-level read-only SQL gate
# (FAST.Runtime.SqlGuard) behind the NL->FHIR query agent. Pinned <0.5 to stay
# compatible with the image's bundled irissqlcli.
RUN pip3 install --target /usr/irissys/mgr/python 'sqlparse<0.5'
COPY --chown=irisowner:irisowner iris/python/fast_sqlguard.py /usr/irissys/mgr/python/

# Bake everything into the image layer:
#  1. create the FAST namespace (HS + interop) and the FHIR R4 endpoint
#  2. wait for the web server (the seed step PUTs to the FHIR endpoint over HTTP)
#  3. load the IPM module: import+compile FAST.*, create web apps, unexpire pw,
#     seed templates/knowledge/cache, load hero+synthetic FHIR, compute
#     embeddings, and start the interoperability production
RUN iris start IRIS quietly \
 && iris session IRIS -U HSLIB < /home/irisowner/app/create-fast-namespace.script \
 && bash -c 'for i in $(seq 1 60); do (echo > /dev/tcp/localhost/52773) >/dev/null 2>&1 && exit 0; sleep 2; done; echo "web server did not come up" >&2; exit 1' \
 && iris session IRIS -U FAST < /home/irisowner/app/iris.script \
 && iris stop IRIS quietly

# The base image entrypoint starts IRIS and keeps the container running.
