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
        # Convert txid string to bytes and then to reversed hex
        txid_bytes = bytes.fromhex(txid)[::-1]  

        # Get the transaction details
        raw_tx = rpc_connection.getrawtransaction(txid_bytes, True)
        
        # Find the output index that corresponds to our taproot address
        vout = None
        for i, output in enumerate(raw_tx['tx'].vout):
            output_info = rpc_connection._call('getaddressinfo', address)
            if 'scriptPubKey' in output_info:
                script_hex = output_info['scriptPubKey']
                if output.scriptPubKey == bytes.fromhex(script_hex):
                    vout = i
                    break

        if vout is None:
            raise ValueError("Couldn't find taproot output in transaction")

        # Create destination address and output
        dest_address = rpc_connection._call('getnewaddress')
        fee = 0.00001
        output_amount = amount - fee

        dest_address_info = rpc_connection._call('getaddressinfo', dest_address)
        script_pubkey = bytes.fromhex(dest_address_info['scriptPubKey'])
        tx_out = CTxOut(int(output_amount * 100000000), script_pubkey)

        # Create unsigned transaction
        tx_in = CTxIn(
            COutPoint(txid_bytes, vout),
            CScript([]),  # Empty scriptSig for witness transactions
            0xffffffff
        )
        
        # Create transaction template for signing
        unsigned_tx = CTransaction([tx_in], [tx_out])
        
        # Create sighash for Taproot
        sighash = unsigned_tx.GetTxid()
        
        # Sign the transaction using the taproot private key with Schnorr signature
        hd_key = HDKey(privkey)
        # Use the sign function with schnorr hash type
        signature = sign(sighash, hd_key, hash_type=0x00)  # SIGHASH_ALL_TAPROOT = 0x00
        
        # Create witness data with stack
        witness_stack = [bytes(signature)]
        script_witness = CScriptWitness(witness_stack)
        witness = CTxInWitness(scriptWitness=script_witness)
        witness_data = CTxWitness([witness])

        # Create transaction with signed input and witness data
        tx = CTransaction([tx_in], [tx_out], witness=witness_data)
        
        # Send the transaction
        raw_tx_hex = tx.serialize().hex()
        txid = rpc_connection._call('sendrawtransaction', raw_tx_hex)
        
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
        address, privkey = create_taproot_address()
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