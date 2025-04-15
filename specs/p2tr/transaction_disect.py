import struct

def dissect_taproot_digest(digest_hex):
    digest = bytes.fromhex(digest_hex)
    offset = 0

    def read_bytes(length):
        nonlocal offset
        data = digest[offset:offset + length]
        offset += length
        return data

    def read_uint8():
        return struct.unpack("B", read_bytes(1))[0]

    def read_uint32():
        return struct.unpack("<I", read_bytes(4))[0]

    def read_bytes32():
        return read_bytes(32).hex()

    parts = {
        "epoch": read_uint8(),
        "hash_type": read_uint8(),
        "nVersion": read_bytes(4).hex(),
        "nLockTime": read_uint32(),
        "sha_prevouts": read_bytes32(),
        "sha_amounts": read_bytes32(),
        "sha_scriptpubkeys": read_bytes32(),
        "sha_sequences": read_bytes32(),
        "sha_outputs": read_bytes32(),
        "spend_type": read_uint8(),
        "input_index": read_uint32()
    }

    return parts

# Copy here the transaction to be dissected 
digest_hex = "000102000000000000003c73862c1686179389acf00e15f069738a5aa87c4e7f500bd382f85c5cc37fa3b223ac0e009cf54402b2529ea4312214616df58c903ec7fd399c12fb08e8e675be45ad9e08ae96e42d7fd1f70a454432049ebd6a625fa377ffa22033fd8692d623e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d21dc2f277a8bbe68327b5e29e5be4318812a068cf4def9aecac78ca4cc775b0ef0000000000"
parsed_digest = dissect_taproot_digest(digest_hex)

# Print output
for key, value in parsed_digest.items():
    print(f"{key}: {value}")