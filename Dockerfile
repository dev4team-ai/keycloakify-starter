# Simple Alpine-based image to serve Keycloakify theme files
FROM alpine:3.19

# Copy theme files to /theme directory
COPY login /theme/login
COPY email /theme/email

# Keep container running (for init container usage)
CMD ["sleep", "infinity"]
