import threading


# A single CPU inference at a time keeps memory and CPU usage predictable on
# the small production service. The shared leaf gate stays cached, while the
# species-specific model is loaded only for the duration of a scan.
inference_lock = threading.Lock()
