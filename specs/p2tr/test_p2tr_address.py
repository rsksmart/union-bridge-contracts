from decimal import Decimal

from bitcoin.rpc import Proxy, JSONRPCError
from bitcoinutils.setup import setup
from bitcoinutils.utils import to_satoshis
from bitcoinutils.transactions import Transaction, TxInput, TxOutput, TxWitnessInput
from bitcoinutils.keys import P2pkhAddress, PrivateKey

# RPC connection settings
RPC_USER = "foo"
RPC_PASSWORD = "rpcpassword"
RPC_HOST = "localhost"
RPC_PORT = 18443


def connect_rpc():
    """Create connection to Bitcoin Core RPC and ensure wallet is loaded"""
    rpc = Proxy(f"http://{RPC_USER}:{RPC_PASSWORD}@{RPC_HOST}:{RPC_PORT}")

    try:
        # Try to create a new wallet if it doesn't exist
        rpc._call('createwallet', 'default')
    except JSONRPCError as e:
        if "Database already exists" not in str(e):
            # If error is not about wallet already existing, try loading it
            try:
                rpc._call('loadwallet', 'default')
            except JSONRPCError:
                print("Could not create or load wallet")
                raise

    return rpc

def fund_address(rpc_connection, address, amount):
    """Fund the taproot address with specified amount"""
    try:
        # Get new address directly from RPC
        new_addr = rpc_connection._call('getnewaddress')
        rpc_connection._call('generatetoaddress', 101, new_addr)

        # Send funds to taproot address
        txid = rpc_connection._call('sendtoaddress', address, amount)

        # Generate a block to confirm the transaction
        new_addr = rpc_connection._call('getnewaddress')
        rpc_connection._call('generatetoaddress', 1, new_addr)

        return txid
    except JSONRPCError as e:
        print(f"RPC Error: {e}")
        raise e

def get_balance(rpc, address):
    descriptor_info = rpc._call('getdescriptorinfo', f"addr({address})")
    utxo_set = rpc._call('scantxoutset', 'start', [descriptor_info['descriptor']])
    return utxo_set['total_amount']

def test_p2tr(rpc, secret_key_from, address_from, address_to, funding_txid, fee):
    # priv = PrivateKey(secret_key_to)
    # priv = PrivateKey("cV3R88re3AZSBnWhBBNdiCKTfwpMKkYYjdiR13HQzsU7zoRNX7JL")
    priv = PrivateKey.from_bytes(bytes.fromhex(secret_key_from))
    pub = priv.get_public_key()

    fromAddress = pub.get_taproot_address()
    assert fromAddress.to_string() == address_from
    print("Address from:", fromAddress.to_string())

    # Get the raw transaction
    raw_tx = rpc._call('getrawtransaction', funding_txid, True)

    # Find our output index
    vout = None
    for i, output in enumerate(raw_tx['vout']):
        if output['scriptPubKey']['address'] == address_from:
            vout = i
            break
    if vout is None:
        raise Exception("Could not find output for address")

    # Get the amount from the raw transaction
    input_amount = to_satoshis(float(raw_tx['vout'][vout]['value']))
    print('Input amount:', input_amount)
    amounts = [input_amount]

    # all scriptPubKeys are needed to sign a taproot input
    # (depending on sighash) but always of the spend input
    first_script_pubkey = fromAddress.to_script_pub_key()
    # alternatively:
    # first_script_pubkey = Script(['OP_1', pub.to_taproot_hex()])

    utxos_script_pubkeys = [first_script_pubkey]

    # toAddress = P2pkhAddress("mtVHHCqCECGwiMbMoZe8ayhJHuTdDbYWdJ")
    toAddress = P2pkhAddress(address_to)

    # create transaction input from tx id of UTXO
    txin = TxInput(funding_txid, vout)

    # create transaction output
    # txOut = TxOutput(to_satoshis(0.99), toAddress.to_script_pub_key())
    output_amount = input_amount - fee
    print('Fee:', fee)
    print('Output amount:', output_amount)
    txOut = TxOutput(output_amount, toAddress.to_script_pub_key())

    # create transaction without change output - if at least a single input is
    # segwit we need to set has_segwit=True
    tx = Transaction([txin], [txOut], has_segwit=True)

    # print("\nRaw transaction:\n" + tx.serialize())
    # print("\ntxid: " + tx.get_txid())
    # print("\ntxwid: " + tx.get_wtxid())

    # sign taproot input
    # to create the digest message to sign in taproot we need to
    # pass all the utxos' scriptPubKeys and their amounts
    sig = priv.sign_taproot_input(tx, 0, utxos_script_pubkeys, amounts)
    # print(sig)

    tx.witnesses.append(TxWitnessInput([sig]))

    # print raw signed transaction ready to be broadcasted
    # print("\nRaw signed transaction:\n" + tx.serialize())
    # print("\nTxId:", tx.get_txid())
    # print("\nTxwId:", tx.get_wtxid())
    # print("\nSize:", tx.get_size())
    # print("\nvSize:", tx.get_vsize())

    txid = rpc._call('sendrawtransaction', tx.serialize())
    print('Sent', txid)
    
    # Generate a block to confirm the transaction
    new_addr = rpc._call('getnewaddress')
    rpc._call('generatetoaddress', 1, new_addr)


if __name__ == "__main__":
    # privkey = '4356879078676432346579865453456786754534567776543424754556472782'
    # address = 'bcrt1plz7zhw6jqvw6ac5d5kzgr68v8vz9yqhdjgfmv2ln8c3p6vdnumhswrrae5'  # my address (regtest)

    secret_key_from = '55d7c5a9ce3d2b15a62434d01205f3e59077d51316f5c20628b3a4b8b2a76f4c'  # LMaB example private key
    # address = 'bc1ppuxgmd6n4j73wdp688p08a8rte97dkn5n70r2ym6kgsw0v3c5ensrytduf'  # LMaB example address (mainnet)
    address_from = 'bcrt1ppuxgmd6n4j73wdp688p08a8rte97dkn5n70r2ym6kgsw0v3c5ense4hynu'  # LMaB example address (regtest)

    # address that our taproot address will pay to
    secret_key_to = 'cV3R88re3AZSBnWhBBNdiCKTfwpMKkYYjdiR13HQzsU7zoRNX7JL'
    address_to = 'mtVHHCqCECGwiMbMoZe8ayhJHuTdDbYWdJ'

    # connect to the node
    rpc = connect_rpc()

    # Fund our taproot address
    amount = 1.0  # BTC
    funding_txid = fund_address(rpc, address_from, amount)
    print('Funding txid:', funding_txid)

    address_to_initial_balance = get_balance(rpc, address_to)
    address_from_initial_balance = get_balance(rpc, address_from)
    print('Address from balance:', address_from_initial_balance)
    print('Address to balance:', address_to_initial_balance)

    fee = 1000000
    setup("regtest")
    test_p2tr(rpc, secret_key_from, address_from, address_to, funding_txid, fee)

    address_to_balance = get_balance(rpc, address_to)
    address_from_balance = get_balance(rpc, address_from)
    print('Address from balance:', address_from_balance)
    print('Address to balance:', address_to_balance)
    assert address_from_balance == address_from_initial_balance - Decimal(amount)
    assert address_to_balance == address_to_initial_balance + Decimal(amount) - Decimal(fee) / Decimal(10 ** 8)
