from decimal import Decimal

from bitcoin.rpc import Proxy, JSONRPCError
from bitcoinutils.setup import setup
from bitcoinutils.script import Script
from bitcoinutils.utils import to_satoshis, ControlBlock
from bitcoinutils.transactions import Transaction, TxInput, TxOutput, TxWitnessInput
from bitcoinutils.keys import P2pkhAddress, P2trAddress, P2wpkhAddress, PrivateKey

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
    priv = PrivateKey.from_bytes(bytes.fromhex(secret_key_from))
    pub = priv.get_public_key()
    print('Public key:', pub.to_hex())

    # btc_reimbursement_pubkey = "741976f972e9aa5e226eae26289b794aac9bbe702f378aa64c6104f16b79298c"
    reimbursement_private_key = PrivateKey(
        "cQwzrJyTNWbEwhPEmQ3Qoo4jSfHdHEtdbL4kNBgHUKhirgzcQw7G"
    )
    reimbursement_public_key = reimbursement_private_key.get_public_key()
    print('Reimbursement public key:', reimbursement_public_key.to_hex())

    # Reimbursement script
    # timelock_script = Script(['OP_10', 'OP_CHECKSEQUENCEVERIFY', 'OP_DROP', '5d238354a7e74c9e373317053226537dec221c5c775bcca01e806ec358c5c08d', 'OP_CHECKSIG'])
    timelock_script = Script.from_raw('5ab275205d238354a7e74c9e373317053226537dec221c5c775bcca01e806ec358c5c08dac')
    print("Script:", timelock_script.get_script())
    print("Script hex:", timelock_script.to_hex())

    # Extra data script
    rootstock_deposit_address = '4C9a9CbFa14106439B0F96a64d9260F3b8947934'
    deposit_amount = 100_000

    # concatenate rootstock_deposit_address and deposit_amount as a hex string
    # we'll always use 4 bytes for the amount
    data = rootstock_deposit_address + deposit_amount.to_bytes(8).hex()
    print("Data:", data)

    # extra_data_script = Script(['OP_RETURN', rootstock_deposit_address, deposit_amount])
    extra_data_script = Script(['OP_RETURN', data])
    print("Extra data script:", extra_data_script.get_script())
    print("Extra data script hex:", extra_data_script.to_hex())

    leafs = [timelock_script, extra_data_script]
    fromAddress = pub.get_taproot_address(leafs)
    print("Address from:", fromAddress.to_string())
    assert fromAddress.to_string() == address_from

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

    # all scriptPubKeys are needed to sign a taproot input
    # (depending on sighash) but always of the spend input
    script_pubkey = fromAddress.to_script_pub_key()

    toAddress = P2pkhAddress(address_to)

    # create transaction input from tx id of UTXO
    # library changes the endianness of the sequence number internally,
    # so this is actually a 10 (0x0000000a)
    txin = TxInput(funding_txid, vout, sequence=b"\x0a\x00\x00\x00")

    # create transaction output
    output_amount = input_amount - fee
    print('Fee:', fee)
    print('Output amount:', output_amount)
    txOut = TxOutput(output_amount, toAddress.to_script_pub_key())

    # create transaction without change output - if at least a single input is
    # segwit we need to set has_segwit=True
    tx = Transaction([txin], [txOut], has_segwit=True)

    # sign taproot input
    sig = reimbursement_private_key.sign_taproot_input(
        tx,
        0,
        [script_pubkey],
        [input_amount],
        script_path=True,
        tapleaf_script=timelock_script,
        tweak=False,
    )

    control_block = ControlBlock(
        pubkey=pub,
        scripts=[leafs],
        index=0,
        is_odd=fromAddress.is_odd()  # shouldn't this be toAddress.is_odd()?
    )

    tx.witnesses.append(TxWitnessInput([
        sig,
        timelock_script.to_hex(),
        control_block.to_hex()
    ]))

    txid = None

    try:
        txid = rpc._call('sendrawtransaction', tx.serialize())
    except JSONRPCError as e:
        assert "non-BIP68-final" in str(e)
    
    assert txid is None

    # Generate enough blocks for timelock to be satisfied
    new_addr = rpc._call('getnewaddress')
    rpc._call('generatetoaddress', 13, new_addr)

    txid = rpc._call('sendrawtransaction', tx.serialize())
    print('Sent', txid)

    # Generate a block to confirm the transaction
    new_addr = rpc._call('getnewaddress')
    rpc._call('generatetoaddress', 1, new_addr)


if __name__ == "__main__":
    secret_key_from = '55d7c5a9ce3d2b15a62434d01205f3e59077d51316f5c20628b3a4b8b2a76f4c'  # LMaB example private key
    # address_from = 'bc1pkxjj2je2dds8nkpcy5pu6maz2uz90we0ne8ng995u3svc22d600sg49t7x'  # mainnet
    # address_from = 'bcrt1pkxjj2je2dds8nkpcy5pu6maz2uz90we0ne8ng995u3svc22d600sjyez3n'  # testnet
    # address_from = 'bcrt1p42u6n8hm5nve0q0rth779lwgpw4hc2vxwty3w8ys6wxp9fx3ghqstempz2'  # testnet OP_CHECKSIG
    # address_from = 'bcrt1pt50s4eyy3zjcvs0p4xpv2vh8gp3jjum4ep5c8tzau87uh5jnekys92yex0'  # testnet OP_CHECKSIG
    # address_from = 'bcrt1prwryjhyj57km40tq2zq997u4fp59cjvaxgzm603kya9lrm5m7xssjan40l'  # testnet timelock
    # address_from = 'bcrt1pyk83zmt0mtrh5vkdxhnnemfk74ls9g94czt997a2fkdd26xk5wfsunaayt'  # testnet timelock + extra data
    # address_from = 'bcrt1p60tcmwu3kzrhyegywl8hjj29akfy6hpn8tq2c4h06kkl0qpwplns2g7zhc'  # testnet timelock + extra data
    address_from = 'bcrt1ptp8gw3yt9rjavkrlxhwmlm9y5w4c5u6yeeltmupanle76eq4ftrszyjhnn'  # testnet timelock + extra data

    # address that our taproot address will pay to
    secret_key_to = 'cV3R88re3AZSBnWhBBNdiCKTfwpMKkYYjdiR13HQzsU7zoRNX7JL'
    address_to = 'mtVHHCqCECGwiMbMoZe8ayhJHuTdDbYWdJ'

    # connect to the node
    rpc = connect_rpc()
    setup("regtest")

    # Fund our taproot address
    amount = 1.0  # BTC
    funding_txid = fund_address(rpc, address_from, amount)
    print('Funding txid:', funding_txid)

    address_from_initial_balance = get_balance(rpc, address_from)
    address_to_initial_balance = get_balance(rpc, address_to)

    print('Address from balance:', address_from_initial_balance)
    print('Address to balance:', address_to_initial_balance)

    fee = 1000000
    test_p2tr(rpc, secret_key_from, address_from, address_to, funding_txid, fee)

    address_to_balance = get_balance(rpc, address_to)
    address_from_balance = get_balance(rpc, address_from)
    print('Address from balance:', address_from_balance)
    print('Address to balance:', address_to_balance)
    assert address_from_balance == address_from_initial_balance - Decimal(amount)
    assert address_to_balance == address_to_initial_balance + Decimal(amount) - Decimal(fee) / Decimal(10 ** 8)
