const crypto = require('crypto');

function normalizeFields(data) {
  return Object.entries(data)
    .filter(([key, value]) => key !== 'signature' && value !== undefined && value !== null)
    .map(([key, value]) => [key, String(value).trim()])
    .filter(([, value]) => value !== '');
}

function encodeValue(value) {
  return encodeURIComponent(value)
    .replace(/[!'()*~]/g, (character) =>
      `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
    )
    .replace(/%20/g, '+');
}

function parameterString(data, phrase) {
  const values = normalizeFields(data)
    .map(([key, value]) => `${key}=${encodeValue(value)}`);
  const normalizedPhrase = String(phrase ?? '').trim();
  if (normalizedPhrase) values.push(`passphrase=${encodeValue(normalizedPhrase)}`);
  return values.join('&');
}

function signature(data, phrase) {
  return crypto.createHash('md5').update(parameterString(data, phrase)).digest('hex');
}

function htmlCheckout(fields, payfastBaseUrl) {
  const inputs = Object.entries(fields)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([key, value]) => [key, String(value).trim()])
    .filter(([, value]) => value !== '')
    .map(
      ([key, value]) =>
        `<input type="hidden" name="${escapeAttribute(key)}" value="${escapeAttribute(value)}">`,
    )
    .join('');
  return `<!doctype html><html><body><form id="payfast" method="post" action="${escapeAttribute(payfastBaseUrl)}/eng/process">${inputs}</form><script>document.getElementById('payfast').submit()</script></body></html>`;
}

function escapeAttribute(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

module.exports = { htmlCheckout, parameterString, signature };
