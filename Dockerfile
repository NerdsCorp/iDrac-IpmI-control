FROM alpine:3.19

# Install ipmitool and bash
RUN apk add --no-cache \
    ipmitool \
    bash \
    tzdata \
    ca-certificates

# Create non-root user for security
RUN addgroup -g 1000 fancontrol && \
    adduser -D -s /bin/bash -u 1000 -G fancontrol fancontrol

# Copy the fan control script
COPY dell-fan-control.sh /usr/local/bin/dell-fan-control.sh

# Make script executable
RUN chmod +x /usr/local/bin/dell-fan-control.sh

# Set ownership
RUN chown fancontrol:fancontrol /usr/local/bin/dell-fan-control.sh

# Switch to non-root user
USER fancontrol

# Set working directory
WORKDIR /home/fancontrol

# Health check to ensure the script is running
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep -f "dell-fan-control.sh" || exit 1

# Default environment variables (can be overridden)
ENV LOG_LEVEL=info
ENV CHECK_INTERVAL=30
ENV TEMP_SENSOR=04h
ENV MAX_TEMP_THRESHOLD=40
ENV HYSTERESIS=2

# Run the fan control script
CMD ["/usr/local/bin/dell-fan-control.sh"]
