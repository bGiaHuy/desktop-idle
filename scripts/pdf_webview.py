"""Local-only WebView2 PDF surface, optionally docked inside the owning terminal.

No browser login/profile is reused. A random loopback URL exposes one selected PDF.
The controller is written by Neovim; removing it terminates this viewer.
"""
import argparse
import ctypes
from ctypes import wintypes
import http.server
import json
import os
from pathlib import Path
import secrets
import threading
import time

import psutil
import webview


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--file', required=True)
    parser.add_argument('--control', required=True)
    parser.add_argument('--pid', required=True, type=int)
    parser.add_argument('--test-seconds', type=float, default=0)
    args = parser.parse_args()
    pdf = Path(args.file).resolve(strict=True)
    if pdf.suffix.lower() != '.pdf':
        raise ValueError('Only PDF files are supported')
    control = Path(args.control)
    token = secrets.token_urlsafe(24)
    metrics = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.split('?')[0] == '/' + token + '/viewer.html':
                page = b'''<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#181825}
iframe{display:block;box-sizing:border-box;width:100%;height:100%;border:2px solid #45475a;border-radius:6px;background:#181825}
</style></head><body><iframe title="PDF reader" src="document.pdf#toolbar=1"></iframe></body></html>'''
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(page)))
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
                self.wfile.write(page)
                return
            if self.path.split('?')[0] != '/' + token + '/document.pdf':
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/pdf')
            self.send_header('Content-Length', str(pdf.stat().st_size))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            metrics['pdf_served'] = True
            with pdf.open('rb') as stream:
                while data := stream.read(256 * 1024):
                    self.wfile.write(data)

        def log_message(self, *_):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}/{token}/viewer.html'
    window = webview.create_window('Desktop Idle PDF', url, width=900, height=850,
                                   frameless=True, hidden=True, background_color='#181825')
    status = control.with_suffix('.status.json')
    user = ctypes.windll.user32
    user.GetParent.argtypes = [wintypes.HWND]
    user.GetParent.restype = wintypes.HWND
    user.SetParent.argtypes = [wintypes.HWND, wintypes.HWND]
    user.SetParent.restype = wintypes.HWND
    user.IsWindow.argtypes = [wintypes.HWND]
    user.GetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int]
    user.SetWindowLongW.argtypes = [wintypes.HWND, ctypes.c_int, ctypes.c_long]
    user.MoveWindow.argtypes = [wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.BOOL]
    user.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
    user.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    own_hwnd = None
    parent = None
    alive = True

    def write_status(**values):
        metrics.update(values)
        status.write_text(json.dumps(metrics), encoding='utf-8')

    def terminal_window():
        ancestors = set()
        try:
            for process in psutil.Process(args.pid).parents():
                if process.name().lower() == 'wezterm-gui.exe':
                    ancestors.add(process.pid)
        except psutil.Error:
            return None
        handles = []
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

        @callback_type
        def visit(hwnd, _):
            pid = wintypes.DWORD()
            user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value in ancestors and user.IsWindowVisible(hwnd):
                handles.append(hwnd)
            return True

        user.EnumWindows(visit, 0)
        return handles[0] if len(handles) == 1 else None

    def shown():
        nonlocal own_hwnd, parent
        own_hwnd = int(window.native.Handle.ToInt64())
        parent = terminal_window()
        if parent:
            # Our own child surface only; never reparent or modify other apps.
            user.SetParent(own_hwnd, parent)
            style = user.GetWindowLongW(own_hwnd, -16)
            user.SetWindowLongW(own_hwnd, -16, (style & ~0x80000000) | 0x40000000)
        write_status(started=True, docked=bool(parent), hwnd=own_hwnd, parent=parent,
                     backend='edgechromium', pdf=str(pdf),border_pixels=2,border_color='#45475a')

    def monitor():
        nonlocal alive
        started = time.monotonic()
        last_rect = None
        last_visible = None
        window.show()
        while alive:
            if args.test_seconds and time.monotonic() - started > args.test_seconds:
                break
            if not control.exists() or not psutil.pid_exists(args.pid):
                break
            try:
                state = json.loads(control.read_text(encoding='utf-8'))
                if own_hwnd:
                    visible = state.get('visible', False)
                    if parent and user.IsWindow(parent):
                        rect = wintypes.RECT()
                        user.GetClientRect(parent, ctypes.byref(rect))
                        width, height = rect.right, rect.bottom
                        x = round(state.get('x', 0) * width)
                        y = round(state.get('y', 0) * height)
                        w = max(100, round(state.get('width', 1) * width))
                        h = max(100, round(state.get('height', 1) * height))
                        if last_rect != (x,y,w,h):
                            user.MoveWindow(own_hwnd, x, y, w, h, True)
                            last_rect = (x,y,w,h)
                    elif parent:
                        break
                    if last_visible != visible:
                        user.ShowWindow(own_hwnd, 4 if visible else 0)
                        last_visible = visible
                    if parent:
                        write_status(visible=visible,rect=[x,y,w,h])
            except (OSError, ValueError):
                pass
            time.sleep(.15)
        alive = False
        window.destroy()

    window.events.shown += shown
    try:
        webview.start(monitor, gui='edgechromium', private_mode=True)
    finally:
        alive = False
        server.shutdown()


if __name__ == '__main__':
    main()
