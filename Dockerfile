FROM alpine

ARG CONFIGURATION

RUN apk add python3 py3-yaml yq-go helm jq

COPY /src /app
COPY /configuration/${CONFIGURATION} /app/configuration.yaml

RUN wget https://raw.githubusercontent.com/yannh/kubeconform/master/scripts/openapi2jsonschema.py -O- > /app/helpers/convert.py 2>/dev/null
