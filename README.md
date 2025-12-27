# Hardware telemetry
A collection of Bash and Python scripts that monitor hardware data, including CPU load, temperature, RAM usage, and optionally, NVIDIA GPU usage (using nvidia-smi). Data are privately shared via a Telegram bot running in Docker.

## Configuration
The scripts require two configuration files. The file `.config` contains a single `int` specifying the thermal zone where CPU temperature is collected. For x86 architectures, this information can be retrieved by inspecting which sensor has type `x86_pkg_temp` in
```bash
cat /sys/class/thermal/thermal_zone*/type
```
and save its value in `.config`. The file `secrets.json` contains the Telegram ChatID and Bot API used by `send.py`, with template
```json
{
    "chatID": "-12345",
    "token": "12345:ABCDE"
}
```
For instruction on creating and maintaining a Telegram Bot, check [BotFather](https://core.telegram.org/bots/tutorial). For security implications, never commit `secrets.json`.

## Instructions
The telemetry script (Bash) can natively run on the system. The Telegram communication (Python) is containerized in rootless [Docker](https://docs.docker.com/) by first running `./build.sh`. Start collecting data by running
```bash
./telemetry.sh [OPTIONS]
    # [OPTIONS]
    # -t, --timestep <seconds> Set the timestep in seconds (default: 30)
    # --nogpu                  Disable GPU monitoring
```

## Structure
The repository has the following structure
```bash
build.sh            # Installation
requirements.txt    # Python dependencies
share.py            # Python Telegram script (baked with Docker)
telemetry.sh        # Main script
```
