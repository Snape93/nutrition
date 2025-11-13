import os
import json
import sys
from pathlib import Path


def setup_module(module):
	# Ensure the app uses testing configuration (in-memory SQLite)
	os.environ['FLASK_ENV'] = 'testing'
	# Use a temporary file-based SQLite DB for stability across connections
	os.environ['TEST_DATABASE_URL'] = os.environ.get('TEST_DATABASE_URL', '') or (
		f"sqlite:///" + str(Path(os.getenv('TEMP') or os.getenv('TMP') or '.')).replace('\\', '/') + "/nutrition_test.db"
	)


def test_register_and_login_flow():
	# Import the Flask app from file path so package naming is not required
	root = Path(__file__).resolve().parent
	if str(root) not in sys.path:
		sys.path.insert(0, str(root))
	from app import app, db  # type: ignore

	with app.app_context():
		# Fresh tables for isolation
		db.drop_all()
		db.create_all()

	client = app.test_client()

	# Register
	register_payload = {
		"username": "testuser1",
		"email": "test1@example.com",
		"password": "Passw0rd!",
		# Minimal required profile; defaults exist but include to be explicit
		"age": 25,
		"sex": "male",
		"weight_kg": 70,
		"height_cm": 175,
		"activity_level": "active",
		"goal": "maintain",
	}
	resp = client.post(
		"/register",
		data=json.dumps(register_payload),
		headers={"Content-Type": "application/json"},
	)
	assert resp.status_code in (200, 201), resp.get_data(as_text=True)
	data = resp.get_json()
	assert data.get("success") is True
	assert data.get("username") == "testuser1"
	assert isinstance(data.get("daily_calorie_goal"), int)

	# Login by username
	login_payload = {"username_or_email": "testuser1", "password": "Passw0rd!"}
	resp = client.post(
		"/login",
		data=json.dumps(login_payload),
		headers={"Content-Type": "application/json"},
	)
	assert resp.status_code == 200, resp.get_data(as_text=True)
	login_data = resp.get_json()
	assert login_data.get("success") is True
	assert login_data.get("username") == "testuser1"

	# Login by email
	login_payload_email = {"username_or_email": "test1@example.com", "password": "Passw0rd!"}
	resp = client.post(
		"/login",
		data=json.dumps(login_payload_email),
		headers={"Content-Type": "application/json"},
	)
	assert resp.status_code == 200, resp.get_data(as_text=True)
	login_data_email = resp.get_json()
	assert login_data_email.get("success") is True
	assert login_data_email.get("email") == "test1@example.com"


