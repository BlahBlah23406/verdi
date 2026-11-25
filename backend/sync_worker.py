"""Optional server-side recurring Plaid sync. Stdlib only; the app need not be open.

Enabled only by VERDI_SYNC_ENABLED=1 (private config/env), live mode only. Uses the
existing consented connection and saved cursor; failures back off exponentially and
persist; auth failures stop retrying until the user reconnects. No file workflows.
"""
import logging
import os
import threading
import time


class SyncWorker:
    def __init__(self, platform, interval=3600, max_backoff=21600, clock=time.time):
        if platform.demo:
            raise ValueError('Background sync is never enabled for demo data.')
        self.platform, self.clock = platform, clock
        self.interval = max(60, int(interval))
        self.max_backoff = max(self.interval, int(max_backoff))
        self._stop = threading.Event()
        self._thread = None

    @classmethod
    def from_env(cls, platform):
        if os.getenv('VERDI_SYNC_ENABLED') != '1' or platform.demo:
            return None
        try:
            return cls(platform, int(os.getenv('VERDI_SYNC_INTERVAL_SECONDS', '3600')), int(os.getenv('VERDI_SYNC_MAX_BACKOFF_SECONDS', '21600')))
        except ValueError:
            raise SystemExit('Sync interval settings must be integers.')

    def backoff(self, failures):
        return min(self.max_backoff, 60 * 2 ** min(failures, self.max_backoff.bit_length()))

    def run_once(self):
        """Sync due users. Returns their current public status."""
        now, results = int(self.clock()), {}
        for uid in self.platform.due_bank_users(now, self.interval):
            try:
                self.platform.sync_bank(uid, now=now, backoff=self.backoff)
            except Exception as error:
                if getattr(error, 'status', None) not in (403, 409, 503):
                    logging.warning('Bank worker could not persist a sync attempt.')
            results[uid] = self.platform.sync_public(uid)['syncStatus']
        return results

    def start(self):
        self._thread = threading.Thread(target=self._loop, daemon=True, name='verdi-sync')
        self._thread.start()

    def stop(self):
        self._stop.set()

    def _loop(self):
        while not self._stop.is_set():
            try:
                self.run_once()
            except Exception:
                logging.warning('Bank worker tick failed. Retrying on next tick.')
            self._stop.wait(min(60, self.interval))
