const { createHash } = require('node:crypto');

function encodePayFastValue(value) {
  return encodeURIComponent(String(value).trim())
    .replace(/[!'()*~]/g, (character) =>
      `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
    )
    .replace(/%20/g, '+');
}

function createPayFastSignature(params, passphrase) {
  const fields = Object.entries(params)
    .filter(
      ([key, value]) =>
        key !== 'signature' && String(value).trim().length > 0,
    )
    .map(([key, value]) => `${key}=${encodePayFastValue(value)}`);
  const signatureString = [
    ...fields,
    `passphrase=${encodePayFastValue(passphrase)}`,
  ].join('&');
  return createHash('md5').update(signatureString).digest('hex');
}

function formatZarAmount(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new TypeError('The transport fee must be a positive amount.');
  }
  return (Math.round((amount + Number.EPSILON) * 100) / 100).toFixed(2);
}

module.exports = { createPayFastSignature, formatZarAmount };
