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
from urllib.parse import urlparse

import psutil
import webview


def main():
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--file')
    source.add_argument('--url')
    parser.add_argument('--control', required=True)
    parser.add_argument('--pid', required=True, type=int)
    parser.add_argument('--test-seconds', type=float, default=0)
    args = parser.parse_args()
    pdf = Path(args.file).resolve(strict=True) if args.file else None
    if pdf and pdf.suffix.lower() != '.pdf':
        raise ValueError('Only PDF files are supported')
    if args.url and urlparse(args.url).scheme not in ('http', 'https', 'about'):
        raise ValueError('Browser supports HTTP/HTTPS URLs only')
    control = Path(args.control)
    pane_id = os.environ.get('WEZTERM_PANE')
    host_state = Path(os.environ.get('TRANSPARENT_CODING_ROOT', control.parent)) / 'cache' / f'webview-pane-{pane_id}.json'
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
    if args.url:
        url = args.url
    window = webview.create_window('Desktop Idle Browser' if args.url else 'Desktop Idle PDF', url, width=900, height=850,
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
    user.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
    user.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
    user.SetWindowPos.argtypes = [wintypes.HWND,wintypes.HWND,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_uint]
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
                     backend='edgechromium', pdf=str(pdf) if pdf else None,browser=bool(args.url),border_pixels=2,border_color='#45475a')

    def install_browser_toolbar():
        # Marshal all WinForms mutations to its UI thread.
        from System import Action
        from System.Drawing import Color, Point, Size
        from System.Windows.Forms import Panel, Button, TextBox, AnchorStyles, DockStyle, Keys

        def create():
            form = window.native
            view = form.browser.webview
            view.Dock = getattr(DockStyle, 'None')
            view.Location = Point(2, 42)
            view.Size = Size(max(1, form.ClientSize.Width - 4), max(1, form.ClientSize.Height - 44))
            view.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            form.BackColor = Color.FromArgb(69, 71, 90)
            bar = Panel()
            bar.Location = Point(2, 2)
            bar.Size = Size(max(1, form.ClientSize.Width - 4), 38)
            bar.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            bar.BackColor = Color.FromArgb(24, 24, 37)
            for index, (label, callback) in enumerate([
                ('<', lambda: view.GoBack() if view.CanGoBack else None),
                ('>', lambda: view.GoForward() if view.CanGoForward else None),
                ('↻', lambda: view.Reload()),
            ]):
                button = Button()
                button.Text = label
                button.Location = Point(4 + index * 34, 4)
                button.Size = Size(32, 30)
                button.ForeColor = Color.FromArgb(205, 214, 244)
                button.BackColor = Color.FromArgb(49, 50, 68)
                button.Click += lambda sender, event, callback=callback: callback()
                bar.Controls.Add(button)
            address = TextBox()
            address.Text = url
            address.Location = Point(110, 9)
            address.Size = Size(max(80, bar.Width - 120), 24)
            address.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            address.BackColor = Color.FromArgb(49, 50, 68)
            address.ForeColor = Color.FromArgb(205, 214, 244)

            def navigate(sender, event):
                if event.KeyCode == Keys.Enter:
                    target = str(address.Text).strip()
                    if '://' not in target and target != 'about:blank':
                        target = ('http://' if target.startswith(('localhost:', 'localhost/', '127.0.0.1:', '127.0.0.1/')) else 'https://') + target
                    if urlparse(target).scheme in ('http', 'https', 'about'):
                        window.load_url(target)
                    event.SuppressKeyPress = True

            def navigated(sender, event):
                if not address.Focused:
                    address.Text = str(view.Source)

            address.KeyDown += navigate
            view.NavigationCompleted += navigated
            bar.Controls.Add(address)
            form.Controls.Add(bar)
            bar.BringToFront()
            write_status(toolbar=True)

        window.native.Invoke(Action(create))

    def monitor():
        nonlocal alive
        started = time.monotonic()
        last_visible = None
        toolbar_installed = False
        # Work in physical coordinates even when monitors have different scaling.
        if hasattr(user, 'SetThreadDpiAwarenessContext'):
            user.SetThreadDpiAwarenessContext.argtypes = [ctypes.c_void_p]
            user.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))
        window.show()
        while alive:
            if args.test_seconds and time.monotonic() - started > args.test_seconds:
                break
            if not control.exists() or not psutil.pid_exists(args.pid):
                break
            try:
                state = json.loads(control.read_text(encoding='utf-8'))
                if own_hwnd:
                    if args.url and not toolbar_installed:
                        install_browser_toolbar()
                        toolbar_installed = True
                    visible = state.get('visible', False)
                    host_overlay = False
                    if pane_id and host_state.exists():
                        try:
                            host = json.loads(host_state.read_text(encoding='utf-8'))
                            host_overlay = host.get('overlay', False)
                            visible = visible and host.get('visible', True)
                        except (ValueError, OSError):
                            pass
                    if parent and user.IsWindow(parent):
                        rect = wintypes.RECT()
                        user.GetClientRect(parent, ctypes.byref(rect))
                        width, height = rect.right, rect.bottom
                        x = max(0, min(width-1, round(state.get('x', 0) * width)))
                        y = max(0, min(height-1, round(state.get('y', 0) * height)))
                        w = max(1, min(width-x, round(state.get('width', 1) * width)))
                        h = max(1, min(height-y, round(state.get('height', 1) * height)))
                        origin = wintypes.POINT(0, 0)
                        user.ClientToScreen(parent, ctypes.byref(origin))
                        actual = wintypes.RECT()
                        user.GetWindowRect(own_hwnd, ctypes.byref(actual))
                        observed = [actual.left-origin.x, actual.top-origin.y,
                                    actual.right-actual.left, actual.bottom-actual.top]
                        # WinForms can reposition the form after the first docking call.
                        # Compare actual native geometry, rather than only the last request.
                        if observed != [x,y,w,h]:
                            user.SetWindowPos(own_hwnd, None, x, y, w, h, 0x0014)
                        user.GetWindowRect(own_hwnd, ctypes.byref(actual))
                        observed = [actual.left-origin.x, actual.top-origin.y,
                                    actual.right-actual.left, actual.bottom-actual.top]
                    elif parent:
                        break
                    if last_visible != visible:
                        user.ShowWindow(own_hwnd, 4 if visible else 0)
                        last_visible = visible
                    if host_overlay and not visible:
                        metrics['overlay_hidden_verified'] = not bool(user.IsWindowVisible(own_hwnd))
                    if parent:
                        write_status(visible=visible,rect=[x,y,w,h],actual_rect=observed,
                                     geometry_matches=observed==[x,y,w,h],host_overlay=host_overlay)
            except (OSError, ValueError):
                pass
            time.sleep(.15)
        alive = False
        window.destroy()

    window.events.shown += shown
    def loaded():
        if args.url:
            values = {'browser_page_loaded': True}
            if args.test_seconds:
                values['test_page_title'] = window.evaluate_js('document.title')
            write_status(**values)
    window.events.loaded += loaded
    try:
        webview.start(monitor, gui='edgechromium', private_mode=True)
    finally:
        alive = False
        server.shutdown()


if __name__ == '__main__':
    main()
