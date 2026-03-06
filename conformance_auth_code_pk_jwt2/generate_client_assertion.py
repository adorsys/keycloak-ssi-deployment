#!/usr/bin/env python3
"""
Generate a client_assertion JWT for Private Key JWT (client-jwt) authentication.

Usage:
    python3 generate_client_assertion.py <client_id> <token_endpoint_url>

Output:
    Prints the signed JWT to stdout.

The private key is the ES256 key embedded in the openid4vc-rest-api-jwt2 client config.
"""

import sys
import time
import uuid
import jwt
from cryptography.hazmat.primitives.asymmetric import ec
import base64


def base64url_decode(s: str) -> bytes:
    """Decode a base64url-encoded string."""
    rem = len(s) % 4
    if rem > 0:
        s += "=" * (4 - rem)
    return base64.urlsafe_b64decode(s)


def build_ec_private_key(d: str, x: str, y: str):
    """Build an EC private key from JWK parameters."""
    d_int = int.from_bytes(base64url_decode(d), byteorder="big")
    return ec.derive_private_key(d_int, ec.SECP256R1())


def generate_client_assertion(client_id: str, token_endpoint: str) -> str:
    """Generate a signed JWT client assertion for private_key_jwt auth."""

    # Private key from the openid4vc-rest-api-jwt2 client JWKS
    jwk = {
        "kty": "EC",
        "d": "-NXwA8OeSDpl40iqXckFzV6dS9o8NcQnZ3iJ8DcOPbE",
        "crv": "P-256",
        "kid": "key-2",
        "x": "Xl7EFTx9oz-A6NiqqD5NMiYCp7-uEHF-esonD6r3T4U",
        "y": "mKYVhYusz1HOeAEB-UoCf2BGPY638H554hP1ebPhKYY",
        "alg": "ES256"
    }

    private_key = build_ec_private_key(jwk["d"], jwk["x"], jwk["y"])

    now = int(time.time())
    payload = {
        "iss": client_id,
        "sub": client_id,
        "aud": token_endpoint,
        "iat": now,
        "exp": now + 300,  # 5 minute expiry
        "jti": str(uuid.uuid4()),
    }

    headers = {
        "kid": jwk["kid"],
        "alg": "ES256",
    }

    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    return token


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(
            "Usage: python3 generate_client_assertion.py <client_id> <token_endpoint_url>",
            file=sys.stderr,
        )
        sys.exit(1)

    client_id = sys.argv[1]
    token_endpoint = sys.argv[2]

    assertion = generate_client_assertion(client_id, token_endpoint)
    print(assertion, end="")
