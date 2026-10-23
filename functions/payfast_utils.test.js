const assert = require('node:assert/strict');
const test = require('node:test');

const {
  createPayFastSignature,
  formatZarAmount,
} = require('./payfast_utils');

test('creates a deterministic signature with PayFast form encoding', () => {
  const params = {
    merchant_id: '10000100',
    item_name: 'Transport fee: Cape Town',
    amount: '125.50',
  };

  assert.equal(
    createPayFastSignature(params, 'sandbox passphrase'),
    '0a5818010ed261caa5461eaf51585581',
  );
});

test('does not include the received signature or empty fields in a signature', () => {
  const params = {
    merchant_id: '10000100',
    empty: '',
    signature: 'untrusted',
  };

  assert.equal(
    createPayFastSignature(params, 'passphrase'),
    createPayFastSignature({ merchant_id: '10000100' }, 'passphrase'),
  );
});

test('formats positive transport fees to two decimal places', () => {
  assert.equal(formatZarAmount(123.456), '123.46');
  assert.equal(formatZarAmount(120), '120.00');
});

test('rejects invalid transport fees', () => {
  assert.throws(() => formatZarAmount(0), TypeError);
  assert.throws(() => formatZarAmount(Number.NaN), TypeError);
});
