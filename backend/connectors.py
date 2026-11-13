"""Server-side Plaid transaction sync. Payments never infer carbon quantities.

Provision a consented access token through Plaid Link before enabling this adapter.
Credentials stay in server configuration. Default API environment is sandbox.
"""
from decimal import Decimal, InvalidOperation
from datetime import date
import json
import os
import urllib.error
import urllib.request


class PaginationChanged(ValueError):
    pass


class PlaidConnector:
    def __init__(self, transport=None):
        self.transport = transport or self._post

    @staticmethod
    def configured(uid):
        return (os.getenv('PLAID_ENV', 'sandbox') in ('sandbox', 'production')
                and uid == os.getenv('PLAID_USER')
                and all(os.getenv(k) for k in ['PLAID_CLIENT_ID', 'PLAID_SECRET', 'PLAID_ACCESS_TOKEN']))

    def _post(self, path, body):
        environment = os.getenv('PLAID_ENV', 'sandbox')
        if environment not in ['sandbox', 'production']:
            raise ValueError('Use sandbox or production Plaid environment.')
        payload = {**body, 'client_id': os.environ['PLAID_CLIENT_ID'], 'secret': os.environ['PLAID_SECRET'], 'access_token': os.environ['PLAID_ACCESS_TOKEN']}
        req = urllib.request.Request(f'https://{environment}.plaid.com{path}', data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json', 'Plaid-Version': '2020-09-14'})
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                return json.loads(response.read(2000000))
        except urllib.error.HTTPError as error:
            with error:
                failure = json.loads(error.read(65536))
            if not isinstance(failure, dict) or not failure.get('error_code'):
                raise ValueError('Plaid returned an unexpected error response.') from None
            return failure

    def fetch(self, cursor=''):
        try:
            return self._fetch_pages(cursor)
        except PaginationChanged:
            # Plaid requires retrying the complete update from the original cursor.
            return self._fetch_pages(cursor)

    def _fetch_pages(self, cursor):
        added, removed = {}, set()
        # Apply only after all pages succeed. A caller retains the old cursor on error.
        for _ in range(100):
            payload = self.transport('/transactions/sync', {'cursor': cursor, 'count': 500})
            if payload.get('error_code') == 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION':
                raise PaginationChanged('Plaid changed transactions during pagination.')
            if payload.get('error_code'):
                raise ValueError('Provider sync failed; retry from the saved cursor.')
            for row in payload.get('added', []) + payload.get('modified', []):
                if row.get('iso_currency_code') != 'USD':
                    continue
                try:
                    value = Decimal(str(row['amount']))
                    if not value.is_finite() or value != value.quantize(Decimal('.01')):
                        raise ValueError('Invalid monetary precision.')
                    cents = int(value * 100)
                    rid, day = row['transaction_id'], row['date']
                    if not isinstance(rid, str) or not rid or not isinstance(day, str):
                        raise ValueError('Invalid transaction identity.')
                    if date.fromisoformat(day).isoformat() != day:
                        raise ValueError('Invalid transaction date.')
                except (KeyError, InvalidOperation, TypeError):
                    raise ValueError('Provider returned invalid money or identity.')
                added[rid] = {'id': rid, 'day': day, 'cents': cents, 'pending': bool(row.get('pending')), 'refund': cents < 0}
                if row.get('pending_transaction_id'):
                    removed.add(row['pending_transaction_id'])
            removed.update(row['transaction_id'] for row in payload.get('removed', []))
            next_cursor = payload.get('next_cursor')
            if not isinstance(next_cursor, str) or (payload.get('has_more') and (not next_cursor or next_cursor == cursor)):
                raise ValueError('Provider returned an invalid pagination cursor.')
            cursor = next_cursor
            if not payload.get('has_more'):
                return {'transactions': list(added.values()), 'removed': list(removed), 'cursor': cursor}
        raise ValueError('Provider pagination exceeded limit. No partial sync applied.')
