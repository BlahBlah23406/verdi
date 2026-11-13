"""Provision a local pilot account and session file without printing its bearer token."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import secrets
import tempfile
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

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
    p.add_argument('--region', choices=v.REGIONS, default='us')
    p.add_argument('--meter-timezone', help='IANA meter time zone, e.g. America/Chicago.')
    args = p.parse_args()
    timezone = args.meter_timezone
    if args.region == 'redmond':
        if timezone and timezone != 'America/Los_Angeles':
            p.error('Redmond meters use America/Los_Angeles.')
        timezone = 'America/Los_Angeles'
    if timezone:
        try:
            ZoneInfo(timezone)
        except (ValueError, ZoneInfoNotFoundError):
            p.error('Use an IANA meter time zone, e.g. America/Los_Angeles.')
    config_path = Path(args.config)
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    sessions = json.loads(config.get('VERDI_SESSIONS_JSON', '{}'))
    app = v.Platform(args.db)
    with app.db() as c:
        c.execute('BEGIN IMMEDIATE')
        c.execute('INSERT OR IGNORE INTO users VALUES(?,?,?,?,0)', (args.user, args.name, args.org, v.REGIONS[args.region]))
        existing = c.execute('SELECT org,region FROM users WHERE id=?', (args.user,)).fetchone()
        if existing['org'] != args.org or existing['region'] != v.REGIONS[args.region]:
            p.error('This account already has a different organization or electricity profile.')
        if any(s['user'] == args.user and s['role'] != args.role for s in sessions.values()):
            p.error('Use a separate account ID for a different role.')
        if timezone:
            saved = c.execute('SELECT meter_timezone FROM pilot_settings WHERE user=?', (args.user,)).fetchone()
            if saved and saved[0] != timezone:
                p.error('This account already has a different meter time zone.')
            c.execute('INSERT OR IGNORE INTO pilot_settings VALUES(?,?)', (args.user, timezone))
        for provider in v.PROVIDERS:
            c.execute('INSERT OR IGNORE INTO connections VALUES(?,?,0)', (args.user, provider))
    sessions[secrets.token_urlsafe(32)] = {'user': args.user, 'org': args.org, 'role': args.role}
    config['VERDI_SESSIONS_JSON'] = json.dumps(sessions)
    with tempfile.NamedTemporaryFile(mode='w', dir=config_path.parent, delete=False) as file:
        private_path = file.name
        try:
            file.write(json.dumps(config, indent=2) + '\n')
            file.close()
            os.replace(private_path, config_path)
        finally:
            Path(private_path).unlink(missing_ok=True)
    print('Pilot account provisioned. Session saved in the private config file. Restart API to load it.')
