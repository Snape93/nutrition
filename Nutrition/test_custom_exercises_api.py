import os
import pytest

os.environ['FLASK_ENV'] = 'testing'

from app import app, db, UserExerciseSubmission  # noqa: E402


@pytest.fixture()
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    with app.app_context():
        db.create_all()
    with app.test_client() as client:
        yield client
    with app.app_context():
        db.drop_all()


def test_submit_custom_exercise(client):
    payload = {
        'user': 'tester',
        'name': 'Shadow Boxing',
        'category': 'Cardio',
        'intensity': 'Medium',
        'duration_min': 15,
        'est_calories': 100,
    }
    res = client.post('/api/exercises/custom', json=payload)
    assert res.status_code in (200, 201)
    data = res.get_json()
    assert data.get('success') is True
    assert isinstance(data.get('id'), int)


def test_list_pending_then_approve(client):
    # Ensure at least one pending exists
    client.post('/api/exercises/custom', json={'user': 'u', 'name': 'Jump Rope', 'duration_min': 5})
    r = client.get('/api/exercises/custom?status=pending')
    assert r.status_code == 200
    items = r.get_json().get('items', [])
    assert len(items) >= 1
    sub_id = items[0]['id']
    approve = client.post(f'/api/exercises/custom/{sub_id}/approve')
    assert approve.status_code == 200
    assert approve.get_json().get('status') == 'approved'


def test_validation_errors(client):
    res = client.post('/api/exercises/custom', json={'user': 'x', 'name': ''})
    assert res.status_code == 400
    res2 = client.post('/api/exercises/custom', json={'user': 'x', 'name': 'A'})
    assert res2.status_code == 400









