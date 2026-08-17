# A container is the awkward case for this board, because it has to read game
# files that live outside it. Nothing here installs a game; the folders are
# mounted in read-only and pointed at with the same environment variables the
# board already understands.
#
# This is the right shape when the games live on a NAS or a shared drive that the
# container host can see. If the games are on the machine you are reading this
# on, running it directly is simpler and the README says so.

FROM python:3.13-slim

# Pillow needs no build tooling on this base image for the wheels it ships, so
# there is deliberately no apt-get layer here.
WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY bmskb ./bmskb
COPY static ./static
COPY templates ./templates
COPY wizzo.py ./

# Caches and settings go to a volume. Without this they would land in /app,
# which is an image layer: the map cache would be rebuilt on every restart, and
# the game folders would have to be re-entered each time.
ENV WIZZO_STATE_DIR=/state
VOLUME ["/state"]

# The board decodes DCS terrain tiles on demand and caches the result, so the
# first chart for a theatre is slow and the rest are not. Give the volume room.
EXPOSE 5000

# --no-update because a container should be replaced by pulling a new image, not
# by rewriting its own files at runtime, which would be discarded anyway.
ENTRYPOINT ["python", "wizzo.py", "--host", "0.0.0.0", "--port", "5000", "--no-update"]
