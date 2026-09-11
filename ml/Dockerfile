FROM python:3.12-slim
WORKDIR /opt/program
COPY ml/model.py ml/job.py ./
COPY src/streamml ./streamml
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ENTRYPOINT ["python3", "/opt/program/job.py"]

