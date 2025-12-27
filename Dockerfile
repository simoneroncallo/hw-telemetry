FROM python:alpine3.23

# Setup
USER root
RUN adduser -D puppet
WORKDIR /home/puppet/work
COPY requirements.txt .
COPY share_data.py .

# Install
RUN pip install --no-cache-dir -r requirements.txt \
	&& chown -R puppet:puppet /home/puppet
# Run
USER puppet
CMD ["python", "share_data.py", "--config", "secrets.json"]
