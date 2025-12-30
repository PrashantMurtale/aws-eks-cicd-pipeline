"""
Simple Flask Application for AWS EKS CI/CD Demo
"""

from flask import Flask, jsonify, request
import os
import socket
from datetime import datetime

app = Flask(__name__)

# Configuration
PORT = int(os.getenv('PORT', 8080))
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
VERSION = os.getenv('VERSION', '1.0.0')

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Welcome to AWS EKS CI/CD Demo Application!',
        'version': VERSION,
        'environment': ENVIRONMENT,
        'hostname': socket.gethostname(),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/health')
def health():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/ready')
def ready():
    """Readiness check endpoint for Kubernetes probes"""
    # Add any dependency checks here (database, cache, etc.)
    return jsonify({
        'status': 'ready',
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/info')
def info():
    """Application info endpoint"""
    return jsonify({
        'app_name': 'eks-cicd-demo',
        'version': VERSION,
        'environment': ENVIRONMENT,
        'hostname': socket.gethostname(),
        'python_version': os.popen('python --version').read().strip(),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/echo', methods=['POST'])
def echo():
    """Echo endpoint for testing"""
    data = request.get_json() or {}
    return jsonify({
        'echo': data,
        'timestamp': datetime.utcnow().isoformat()
    })

@app.errorhandler(404)
def not_found(e):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Not Found',
        'message': 'The requested resource was not found',
        'status_code': 404
    }), 404

@app.errorhandler(500)
def internal_error(e):
    """Handle 500 errors"""
    return jsonify({
        'error': 'Internal Server Error',
        'message': 'An unexpected error occurred',
        'status_code': 500
    }), 500

if __name__ == '__main__':
    print(f"Starting application on port {PORT}")
    print(f"Environment: {ENVIRONMENT}")
    print(f"Version: {VERSION}")
    app.run(host='0.0.0.0', port=PORT, debug=(ENVIRONMENT == 'development'))
