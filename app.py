from flask import Flask, send_from_directory
import os

app = Flask(__name__)
PORT = int(os.environ.get('PORT', 8080))

@app.route('/')
def index():
    return send_from_directory('public', 'index.html')

@app.route('/<path:filename>')
def static_files(filename):
    return send_from_directory('public', filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT, debug=False)
