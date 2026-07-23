# Chaos Engine verdict reporter (platform-overhaul #794/#812). Dependency-free (stdlib urllib),
# so a slim python base is all it needs. Invoked by the dual-gate Workflow's verdict node as /report.
FROM python:3.12-slim
WORKDIR /app
COPY report.py /app/report.py
RUN printf '#!/bin/sh\nexec python /app/report.py "$@"\n' > /report && chmod +x /report
ENTRYPOINT ["/report"]
