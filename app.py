import http.server
import os
import socketserver

PORT = int(os.environ.get('PORT', 8080))

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = '/finance-app.html'
        return super().do_GET()

    def log_message(self, format, *args):
        print(f"[{self.address_string()}] {format % args}")

with socketserver.TCPServer(('0.0.0.0', PORT), Handler) as httpd:
    print(f"Finance App running on port {PORT}")
    httpd.serve_forever()
