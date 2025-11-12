# Debian-slim variant that keeps image small but allows apt installs for build deps.
FROM python:3.9-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Install build/runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    lsb-release \
    gnupg2 \
    unixodbc-dev \
    odbcinst \
    git \
    python3-venv \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    libsasl2-dev \
    tzdata && \
    rm -rf /var/lib/apt/lists/*

# Copy the full repository into the image so any local path dependencies in
# requirements.txt (for example ./soda/core) exist when pip runs.
COPY . /app
WORKDIR /app

# Create venv and install requirements (now local paths referenced in requirements.txt are present)
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip setuptools wheel \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# (rest of Dockerfile: copy entrypoint/users etc)
# ENTRYPOINT ["soda"]
CMD ["scan"]

# Install Microsoft ODBC driver (keeps the same steps you had; note compatibility caveats)
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/21.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 mssql-tools unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Dremio ODBC driver via RPM conversion (alien). alien is installed transiently to perform the conversion.
RUN apt-get update && apt-get install -y --no-install-recommends alien && \
    curl -L https://download.dremio.com/arrow-flight-sql-odbc-driver/arrow-flight-sql-odbc-driver-LATEST.x86_64.rpm -o arrow-driver.rpm && \
    alien -iv --scripts arrow-driver.rpm && \
    rm -f arrow-driver.rpm && \
    apt-get purge -y --auto-remove alien && \
    rm -rf /var/lib/apt/lists/*

# Entrypoint uses venv-installed console scripts thanks to PATH including /opt/venv/bin
ENTRYPOINT ["soda"]

CMD ["scan"]
