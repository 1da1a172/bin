#! /usr/bin/env python3
# Source: https://gist.github.com/theychx/696baa120b7d9c35b2696c136eb35722

import os
import signal
import sys
import tempfile
import threading

import pychromecast


class Cache:
    def __init__(self):
        cache_dir = os.path.join(tempfile.gettempdir(), 'cc-play')
        self.cache_filename = os.path.join(cache_dir, 'host')

        try:
            os.mkdir(cache_dir)
        except FileExistsError:
            pass

    def get(self):
        try:
            with open(self.cache_filename, 'r') as cache:
                return cache.read()
        except FileNotFoundError:
            return None

    def set(self, value):
        with open(self.cache_filename, 'w') as cache:
            cache.write(value)


class StatusListener:
    def __init__(self, running_app, id='CC1AD845'):
        self.id = id
        self._ready = True if running_app == self.id else False
        self._playback_start = False
        self.playback_end = threading.Event()

    def new_cast_status(self, status):
        if status.app_id == self.id:
            self._ready = True
        elif self._ready:
            self.playback_end.set()

    def new_media_status(self, status):
        if self._ready:
            if not self._playback_start:
                if status.player_state == 'BUFFERING':
                    self._playback_start = True
            else:
                if status.player_state in ['UNKNOWN', 'IDLE']:
                    self.playback_end.set()


class MediaPlayback:
    def __init__(self):
        cache = Cache()
        cached_ip = cache.get()

        try:
            if not cached_ip:
                raise ValueError
            self.cast = pychromecast.Chromecast(cached_ip)
        except (pychromecast.error.ChromecastConnectionError, ValueError):
            devices = pychromecast.get_chromecasts()
            self.cast = min(devices, key=lambda cc: cc.name)
            cache.set(self.cast.host)

        self.cast.wait()
        self.listener = StatusListener(self.cast.app_id)

    def play(self, url):
        self.cast.play_media(url, content_type='video/mp4')
        self.cast.register_status_listener(self.listener)
        self.cast.media_controller.register_status_listener(self.listener)
        self.listener.playback_end.wait()

    def stop(self):
        self.cast.media_controller.stop()


def signal_handler(*args):
    raise KeyboardInterrupt


def main(url):
    signal.signal(signal.SIGINT, signal_handler)
    pb = MediaPlayback()

    try:
        pb.play(url)
    except KeyboardInterrupt:
        pb.stop()


if __name__ == '__main__':
    try:
        main(sys.argv[1])
    except IndexError:
        sys.exit('please specify an url')
