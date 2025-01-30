import hashlib
from bitcoinlib.transactions import Transaction, Input, Output
from bitcoinlib.keys import HDKey, sign
from bitcoinlib.scripts import Script
from bitcoinlib.encoding import to_bytes, to_hexstring
from bitcoin.core import COutPoint, CTxIn, CTxOut, CTransaction, CTxInWitness, CTxWitness, CScriptWitness
from bitcoin.core.script import CScript, OP_1
from bitcoin.wallet import CBitcoinSecret, CBitcoinAddress
from bitcoin.rpc import Proxy, JSONRPCError
import os
import time

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

def create_taproot_address():
    """Create a taproot address and return the address and private key"""
    # Generate a random private key
    privkey = os.urandom(32)
    internal_key = HDKey(privkey, network='regtest')

    # Create taproot address using the internal key
    # HDKey can generate addresses directly
    address = internal_key.address(script_type='p2tr')

    return str(address), privkey

def fund_address(rpc_connection, address, amount):
    """Fund the taproot address with specified amount"""
    try:
        # Generate some blocks if needed to have funds
        if float(rpc_connection._call('getbalance')) < amount:
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
        # return None

def spend_from_taproot(rpc_connection, address, privkey, txid, amount):
    """Spend funds from the taproot address using key spend path"""
    try:
        # Get the raw transaction to get output index and script
        raw_tx = rpc_connection._call('getrawtransaction', txid, True)

        # Find our output index
        vout = None
        for i, output in enumerate(raw_tx['vout']):
            if output['scriptPubKey']['address'] == address:
                vout = i
                break
        if vout is None:
            raise Exception("Could not find output for address")

        # Get the input value from the previous transaction
        input_value = int(float(raw_tx['vout'][vout]['value']) * 100000000)  # Convert BTC to satoshis
        
        # Create destination address for the spend
        dest_address = rpc_connection._call('getnewaddress', "", "bech32")
        
        # Calculate fee and amount to send (sending amount - fee)
        fee = 0.0001  # 10000 satoshis
        send_amount = amount - fee
        
        # Create unsigned transaction
        inputs = [{'txid': txid, 'vout': vout}]
        outputs = {dest_address: send_amount}
        unsigned_tx = rpc_connection._call('createrawtransaction', inputs, outputs)
        
        # Convert private key to HDKey for signing
        internal_key = HDKey(bytes.fromhex(privkey), network='regtest')
        
        # Create transaction object
        tx = Transaction.parse_hex(unsigned_tx)
        
        # Set witness type on transaction
        tx.witness_type = 'segwit'
        
        # Get the locking script from the previous transaction
        locking_script = bytes.fromhex(raw_tx['vout'][vout]['scriptPubKey']['hex'])
        
        # Configure the input properly for Taproot
        tx.inputs[0].witness_type = 'segwit'
        tx.inputs[0].script_type = 'p2tr'
        tx.inputs[0].keys = [internal_key]
        tx.inputs[0].unlocking_script = b''  # Empty scriptSig as required for witness
        tx.inputs[0].value = input_value  # Set the input value
        tx.inputs[0].locking_script = locking_script  # Set the locking script
        tx.inputs[0].redeemscript = locking_script  # Use locking script as redeem script for Taproot
        tx.inputs[0].witnesses = [b'']  # Initialize empty witness
        
        # Sign the transaction
        tx.sign(internal_key)
        
        # Send the signed transaction
        signed_tx_hex = tx.raw_hex()
        txid = rpc_connection._call('sendrawtransaction', signed_tx_hex)

        return txid

    except Exception as e:
        print(f"Error spending from taproot: {e}")
        raise e

def main():
    """Main function to test taproot address creation and spending"""
    try:
        # Connect to Bitcoin Core
        rpc = connect_rpc()
        
        # Create taproot address
        # address, privkey = create_taproot_address()
        privkey = '4356879078676432346579865453456786754534567776543424754556472782'
        address = 'bcrt1plz7zhw6jqvw6ac5d5kzgr68v8vz9yqhdjgfmv2ln8c3p6vdnumhswrrae5'  # my address (regtest)
        # address = 'bc1plz7zhw6jqvw6ac5d5kzgr68v8vz9yqhdjgfmv2ln8c3p6vdnumhs5jl5kp'  # my address (mainnet)

        # privkey = '55d7c5a9ce3d2b15a62434d01205f3e59077d51316f5c20628b3a4b8b2a76f4c'  # LMaB example private key
        # address = 'bc1ppuxgmd6n4j73wdp688p08a8rte97dkn5n70r2ym6kgsw0v3c5ensrytduf'  # LMaB example address (mainnet)
        # address = 'bcrt1ppuxgmd6n4j73wdp688p08a8rte97dkn5n70r2ym6kgsw0v3c5ense4hynu'  # LMaB example address (regtest)

        print(f"Created taproot address: {address}")

        # Fund the address
        amount = 1.0  # BTC
        txid = fund_address(rpc, address, amount)
        if txid:
            print(f"Funded address with {amount} BTC. TXID: {txid}")

            # Wait a bit for transaction to be fully processed
            time.sleep(2)

            # Spend from the address
            spend_txid = spend_from_taproot(rpc, address, privkey, txid, amount)
            if spend_txid:
                print(f"Successfully spent funds. TXID: {spend_txid}")
            else:
                print("Failed to spend funds")
        else:
            print("Failed to fund address")

    except Exception as e:
        # print(f"Error in main: {e}")
        raise e

if __name__ == "__main__":
    main()
