FROM swipl:9.3.25
ENV DEBIAN_FRONTEND=noninteractive
ARG PETTA_REF=700707a68053640846dc5e36e38d54a6b5503869

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git build-essential curl \
    && rm -rf /var/lib/apt/lists/* \
    && swipl --version \
    && dpkg --compare-versions "$(swipl --version | awk '{print $3}')" ge 9.3.0

RUN swi_py=$(swipl -q -g "use_module(library(janus)), py_call(sys:version, V), writeln(V), halt." \
        | awk '{print $1}' | cut -d. -f1,2) \
    && apt-get update && apt-get install -y --no-install-recommends \
        "libpython${swi_py}-stdlib" "python${swi_py}" "python${swi_py}-dev" "python${swi_py}-venv" \
    && rm -rf /var/lib/apt/lists/* \
    && "/usr/bin/python${swi_py}" -m venv /opt/metamo-venv

ENV VIRTUAL_ENV=/opt/metamo-venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN git init /opt/PeTTa \
    && git -C /opt/PeTTa remote add origin https://github.com/trueagi-io/PeTTa.git \
    && git -C /opt/PeTTa fetch --depth 1 origin "$PETTA_REF" \
    && git -C /opt/PeTTa checkout --detach FETCH_HEAD

RUN printf '#!/bin/bash\n\
FILE_PATH=$(realpath "$1")\n\
cd /opt/PeTTa || exit 1\n\
sh run.sh "$FILE_PATH"\n' \
> /usr/local/bin/petta \
&& chmod +x /usr/local/bin/petta

WORKDIR /app
COPY requirements.txt .
RUN python -m pip install --upgrade pip \
    && python -m pip install -r requirements.txt \
    && python -m pip install /opt/PeTTa

COPY . .
ENV QWESTOR_USECASE_DIR=/app/usecase

CMD ["uvicorn", "usecase.service.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
