# A tiny container image. Built in the cloud with `az acr build`,
# so no Docker daemon is needed (Cloud Shell doesn't have one).
FROM nginx:alpine

# Serve our page instead of the nginx default.
COPY index.html /usr/share/nginx/html/index.html

# Document the port the container listens on.
EXPOSE 80

# Prove the container is healthy to Kubernetes.
HEALTHCHECK --interval=10s --timeout=3s CMD wget -qO- http://localhost/ || exit 1
