# Debian-slim variant that keeps image small but allows installing Microsoft ODBC & RPM drivers.
FROM python:3.9-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

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
        tzdata && \
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

# Create and use an isolated venv for all Python packages (clean venv installation).
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip setuptools wheel && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

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

# Copy application sources (do this after dependency installation to maximize build cache)
COPY . .

# Entrypoint uses venv-installed console scripts thanks to PATH including /opt/venv/bin
ENTRYPOINT ["soda"]
CMD ["scan"]
