# Dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY app.py .
RUN pip install flask requests datadog

# Install Datadog agent (simplified for demo)
RUN apt-get update && apt-get install -y curl \
    && DD_API_KEY=<your-datadog-api-key> DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)" \
    && apt-get clean

EXPOSE 5000
CMD ["sh", "-c", "service datadog-agent start && python app.py"]
# TODO: Ticket #504 - Optimize Datadog agent
# Current Issue: Full agent install is heavy for Fargate; use a lighter sidecar or ECS integration
