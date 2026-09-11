FROM python:3.12-alpine
# This pure-stdlib workload has no glibc/native-extension dependency.
# Apply available fixes, then require the same ECR HIGH/CRITICAL release gate.
RUN apk upgrade --no-cache
WORKDIR /opt/program
COPY ml/model.py ml/job.py ./
COPY src/streamml ./streamml
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ENTRYPOINT ["python3", "/opt/program/job.py"]
