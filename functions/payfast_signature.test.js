const assert = require('node:assert/strict');
const test = require('node:test');
const { htmlCheckout, parameterString, signature } = require('./payfast_signature');

test('signature uses PayFast RFC 1738 encoding and excludes empty fields', () => {
  const fields = {
    merchant_id: ' 10000100 ',
    item_name: "trip !'()*~",
    email_address: ' ',
    signature: 'ignored',
  };

  assert.equal(
    parameterString(fields, ' pass phrase '),
    'merchant_id=10000100&item_name=trip+%21%27%28%29%2A%7E&passphrase=pass+phrase',
  );
  assert.equal(
    signature(fields, ' pass phrase '),
    '9be275bdfe5d7a12b2ee28344197aa20',
  );
});

test('checkout submits the normalized fields used for signing', () => {
  const html = htmlCheckout(
    {
      name_first: ' Rider ',
      email_address: ' ',
      item_name: 'Trip & <Friends>',
      signature: 'abc123',
    },
    'https://sandbox.payfast.co.za',
  );

  assert.match(html, /name="name_first" value="Rider"/);
  assert.doesNotMatch(html, /name="email_address"/);
  assert.match(html, /name="item_name" value="Trip &amp; &lt;Friends&gt;"/);
  assert.match(html, /name="signature" value="abc123"/);
});
