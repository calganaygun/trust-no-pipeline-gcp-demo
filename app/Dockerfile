# Hardened Dockerfile — Pinned by Immutable Digest & Running as Non-Root (UID 65532)
FROM python:3.12-slim@sha256:aa943ce411423c7582288f18707ff66eddcbaeb510502d747a72aeb34f30d159

WORKDIR /app
COPY main.py /app/main.py

# Run as non-root user (UID 65532)
USER 65532:65532
EXPOSE 8080

ENTRYPOINT ["python3", "/app/main.py"]
