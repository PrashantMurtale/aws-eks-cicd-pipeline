"""
Unit tests for the Flask application
"""

import pytest
import json
from app import app

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_home_endpoint(client):
    """Test home endpoint returns correct response"""
    response = client.get('/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'message' in data
    assert 'Welcome' in data['message']
    assert 'version' in data
    assert 'environment' in data

def test_health_endpoint(client):
    """Test health endpoint returns healthy status"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'timestamp' in data

def test_ready_endpoint(client):
    """Test readiness endpoint returns ready status"""
    response = client.get('/ready')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'ready'
    assert 'timestamp' in data

def test_info_endpoint(client):
    """Test info endpoint returns application info"""
    response = client.get('/info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'app_name' in data
    assert 'version' in data
    assert 'environment' in data
    assert 'hostname' in data

def test_echo_endpoint(client):
    """Test echo endpoint echoes back JSON data"""
    test_data = {'message': 'Hello, World!', 'number': 42}
    response = client.post(
        '/api/echo',
        data=json.dumps(test_data),
        content_type='application/json'
    )
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['echo'] == test_data
    assert 'timestamp' in data

def test_echo_endpoint_empty(client):
    """Test echo endpoint with empty body"""
    response = client.post('/api/echo')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['echo'] == {}

def test_404_error(client):
    """Test 404 error handling"""
    response = client.get('/nonexistent-endpoint')
    assert response.status_code == 404
    data = json.loads(response.data)
    assert 'error' in data
    assert data['status_code'] == 404
