# Use official Nginx base image
FROM nginx:alpine

# Create a directory for EFS mount point, ECS does not create it automatically.
# This directory will be used to mount the EFS file system
RUN mkdir -p /mnt/efs

# Copy your static site into the default Nginx folder
COPY app/index.html /usr/share/nginx/html/index.html

EXPOSE 80


