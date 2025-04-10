# app.py
from flask import Flask, jsonify
import requests
from datadog import initialize, statsd

app = Flask(__name__)

# Initialize Datadog
options = {
    'statsd_host': '127.0.0.1',  # Datadog agent in sidecar
    'statsd_port': 8125
}
initialize(**options)

@app.route('/users', methods=['GET'])
def get_users():
    statsd.increment('flask.requests', tags=["endpoint:/users"])
    response = requests.get('https://reqres.in/api/users')
    if response.status_code == 200:
        statsd.gauge('flask.response_time', response.elapsed.total_seconds(), tags=["endpoint:/users"])
        return jsonify(response.json())
    return jsonify({"error": "Failed to fetch users"}), 500

@app.route('/posts', methods=['GET'])
def get_posts():
    # TODO: Ticket #123 - Implement fetching posts
    statsd.increment('flask.requests', tags=["endpoint:/posts"])
    return jsonify({"message": "Not implemented yet"}), 501

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
