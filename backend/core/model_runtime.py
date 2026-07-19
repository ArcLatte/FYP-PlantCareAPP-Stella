import threading


# Keep the complete leaf-gate -> disease-model sequence single-file on the
# small production service. An RLock lets the pipeline hold the lock across
# both stages while each classifier keeps its own defensive lock.
inference_lock = threading.RLock()
