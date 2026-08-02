FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PETTA_REF=v1.0.2

RUN apt-get update && apt-get install -y --no-install-recommends \
      software-properties-common ca-certificates git build-essential curl \
    && add-apt-repository -y ppa:swi-prolog/stable \
    && apt-get update && apt-get install -y --no-install-recommends swi-prolog \
    && rm -rf /var/lib/apt/lists/*

RUN swi_py=$(swipl -q -g "use_module(library(janus)), py_call(sys:version, V), writeln(V), halt." \
        | awk '{print $1}' | cut -d. -f1,2) \
    && apt-get update && apt-get install -y --no-install-recommends \
        "libpython${swi_py}-stdlib" "python${swi_py}" "python${swi_py}-dev" "python${swi_py}-venv" \
    && rm -rf /var/lib/apt/lists/* \
    && "/usr/bin/python${swi_py}" -m venv /opt/metamo-venv

ENV VIRTUAL_ENV=/opt/metamo-venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN git clone --depth 1 --branch "$PETTA_REF" https://github.com/trueagi-io/PeTTa.git /opt/PeTTa

RUN printf '#!/bin/bash\n\
FILE_PATH=$(realpath "$1")\n\
cd /opt/PeTTa || exit 1\n\
sh run.sh "$FILE_PATH"\n' \
> /usr/local/bin/petta \
&& chmod +x /usr/local/bin/petta

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install -r requirements.txt \
    && pip install /opt/PeTTa 

COPY . .
ENV QWESTOR_USECASE_DIR=/app/usecase

CMD ["uvicorn", "usecase.service.api.main:app", "--host", "0.0.0.0", "--port", "8000"]