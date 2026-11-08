"""Plaid protocol contract tests. No external credentials or network required."""
import unittest
from connectors import PlaidConnector


class ConnectorTests(unittest.TestCase):
    def test_pagination_pending_replacement_and_removals(self):
        pages = iter([
            {'added':[{'transaction_id':'posted','pending_transaction_id':'pending','amount':12.45,'date':'2026-10-02','iso_currency_code':'USD'}], 'next_cursor':'page-1','has_more':True},
            {'modified':[{'transaction_id':'refund','amount':-12.45,'date':'2026-10-03','iso_currency_code':'USD'}], 'removed':[{'transaction_id':'removed'}], 'next_cursor':'page-2','has_more':False},
        ])
        cursors=[]
        def transport(path,body):
            self.assertEqual(path,'/transactions/sync')
            cursors.append(body['cursor'])
            return next(pages)
        result=PlaidConnector(transport).fetch()
        self.assertEqual(cursors,['','page-1'])
        self.assertEqual(result['cursor'],'page-2')
        self.assertEqual(result['transactions'][0]['cents'],1245)
        self.assertTrue(result['transactions'][1]['refund'])
        self.assertEqual(set(result['removed']),{'pending','removed'})

    def test_invalid_money_and_currency(self):
        for amount in ['NaN','Infinity','12.451']:
            with self.assertRaises(ValueError):
                PlaidConnector(lambda *_:{'added':[{'amount':amount,'iso_currency_code':'USD'}]}).fetch()
        result=PlaidConnector(lambda *_:{'added':[{'amount':12.45,'iso_currency_code':'EUR'}],'next_cursor':'new','has_more':False}).fetch()
        self.assertEqual(result['transactions'],[])

    def test_failed_page_and_stalled_cursor_do_not_return_partial_data(self):
        with self.assertRaises(ValueError):
            PlaidConnector(lambda *_:{'next_cursor':'old','has_more':True}).fetch('old')
        with self.assertRaises(ValueError):
            PlaidConnector(lambda *_:{'error_code':'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION'}).fetch()


if __name__=='__main__': unittest.main()
