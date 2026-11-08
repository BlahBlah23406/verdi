"""Provision a local pilot account and session file without printing its bearer token."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import secrets

spec = importlib.util.spec_from_file_location('verdi_platform', Path(__file__).with_name('platform.py'))
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--db', required=True)
    p.add_argument('--config', required=True, help='Private JSON outside the repository.')
    p.add_argument('--user', required=True)
    p.add_argument('--name', required=True)
    p.add_argument('--org', required=True)
    p.add_argument('--role', choices=['consumer', 'analyst'], default='consumer')
    args = p.parse_args()
    app = v.Platform(args.db)
    with app.db() as c:
        c.execute('INSERT OR IGNORE INTO users VALUES(?,?,?,?,0)', (args.user, args.name, args.org, 'US national fallback'))
        for provider in v.PROVIDERS:
            c.execute('INSERT OR IGNORE INTO connections VALUES(?,?,0)', (args.user, provider))
    config_path = Path(args.config)
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    sessions = json.loads(config.get('VERDI_SESSIONS_JSON', '{}'))
    sessions[secrets.token_urlsafe(32)] = {'user': args.user, 'org': args.org, 'role': args.role}
    config['VERDI_SESSIONS_JSON'] = json.dumps(sessions)
    config_path.write_text(json.dumps(config, indent=2)+'\n')
    os.chmod(config_path,0o600)
    print('Pilot account provisioned. Session saved in the private config file. Restart API to load it.')
