import asyncio
import time
from aptos_sdk.account_address import AccountAddress
from aptos_sdk.async_client import (
    ApiError,
    EntryFunction,
    RestClient,
    TransactionArgument,
    TransactionPayload,
    RawTransaction,
)
from aptos_sdk.bcs import Serializer
from aptos_sdk.transactions import SignedTransaction
from aptos_sdk import ed25519

NODE_URL = 'https://rpc-testnet.supra.com/rpc/v3'
SENDER_ADDR_HEX = '0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0'
PRIVATE_KEY_HEX = '0x45550bb6f4eb8cc51513e961c5b9b504b127d234c9239729a9adda6e034c1421'
CHAIN_ID = 6
GAS_UNIT_PRICE = 100
MAX_GAS_AMOUNT = 50000
EXPIRATION_SECS = 300


def u128_arg(value: int) -> TransactionArgument:
    return TransactionArgument(value, Serializer.u128)


async def main():
    rest_client = RestClient(NODE_URL)
    try:
        account_address = AccountAddress.from_str(SENDER_ADDR_HEX)
        account_info = await rest_client.account(account_address)
        sequence_number = int(account_info['sequence_number'])

        priv_key = ed25519.PrivateKey.from_hex(PRIVATE_KEY_HEX)

        entry_function = EntryFunction.natural(
            f"{SENDER_ADDR_HEX}::core_main_v2",
            'record_client_whitelist_snapshot',
            [],
            [
                u128_arg(1000),
                u128_arg(200000),
                u128_arg(13500000000),
            ],
        )

        payload = TransactionPayload(entry_function)
        expiration_timestamps_secs = int(time.time()) + EXPIRATION_SECS

        raw_txn = RawTransaction(
            sender=account_address,
            sequence_number=sequence_number,
            payload=payload,
            max_gas_amount=MAX_GAS_AMOUNT,
            gas_unit_price=GAS_UNIT_PRICE,
            expiration_timestamps_secs=expiration_timestamps_secs,
            chain_id=CHAIN_ID,
        )

        authenticator = raw_txn.sign(priv_key)
        signed_txn = SignedTransaction(raw_txn, authenticator)

        try:
            resp = await rest_client.submit_bcs_transaction(signed_txn)
            print(resp)
        except ApiError as exc:
            print(f"API error: {exc}")
            print(f"Response text: {exc.args[0]}")\n            print(f"Status code: {exc.status_code}")
            raise
    finally:
        await rest_client.close()


if __name__ == '__main__':
    asyncio.run(main())

