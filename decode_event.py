#!/usr/bin/env python3
"""
Decode PegoutRegistered event data
"""
from eth_abi import decode
from eth_utils import decode_hex, to_checksum_address

# Topics from the log (indexed parameters)
topics = [
    "0xf6052dd9927cbc3917a92c3f54c45d6f1d457f46b6694a4c46e881254ee538aa",  # event signature
    "0x0000000000000093bab0ffedba1852745675a6edc507451bcf5250ce7734a84b",  # blockHash
    "0x31b2a5d0111a195003ac6cd3152bc853ee7714979db86e5f16e3f54f518757c0",  # txid
    "0xac6a2f97e22ca55131c5b789c489918f4dc5dab265dc86068c11ad8738393f4f"   # acceptPeginTxid
]

# Raw data from the log (data field - non-indexed parameters)
raw_data = """
00000000000000000000000000000000ac2b757f148204cc6c3f9880f8a8cc2f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
"""

# Remove whitespace and combine
raw_data = raw_data.replace('\n', '').replace(' ', '').strip()
# Remove 0x prefix if present
if raw_data.startswith('0x'):
    raw_data = raw_data[2:]
# Pad to even length if needed
if len(raw_data) % 2 != 0:
    raw_data = raw_data + '0'
raw_data_bytes = decode_hex(raw_data)

# Event structure:
# PegoutRegistered(
#     bytes32 indexed blockHash,      // topics[1]
#     bytes32 indexed txid,           // topics[2]
#     bytes32 indexed acceptPeginTxid, // topics[3]
#     uint128 committeeId,            // data[0]
#     uint64 streamId,                // data[1]
#     uint64 packetNumber,            // data[2]
#     uint64 slotId                   // data[3]
# )

# Decode topics (indexed parameters)
blockHash = topics[1]
txid = topics[2]
acceptPeginTxid = topics[3]

# Decode data (non-indexed parameters)
types = [
    'uint128',  # committeeId
    'uint64',   # streamId
    'uint64',   # packetNumber
    'uint64'    # slotId
]

try:
    # Decode using eth_abi
    decoded = decode(types, raw_data_bytes)
    
    committeeId = decoded[0]
    streamId = decoded[1]
    packetNumber = decoded[2]
    slotId = decoded[3]
    
    # Print results
    print("=" * 80)
    print("PegoutRegistered Event Decoded")
    print("=" * 80)
    print()
    print("Indexed Parameters (from topics):")
    print(f"  blockHash: {blockHash}")
    print(f"  txid: {txid}")
    print(f"  acceptPeginTxid: {acceptPeginTxid}")
    print()
    print("Non-indexed Parameters (from data):")
    print(f"  committeeId: {committeeId}")
    print(f"  streamId: {streamId}")
    print(f"  packetNumber: {packetNumber}")
    print(f"  slotId: {slotId}")
    print()
    
except Exception as e:
    print(f"Error decoding: {e}")
    import traceback
    traceback.print_exc()
