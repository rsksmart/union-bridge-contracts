require_relative 'common.rb' # common functions
require_relative 'bech32.rb'
require "digest" # library for SHA256 hash function

# =========
# Construct
# =========

# ----------
# Public Key
# ----------

internal_pubkey = '924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329'

# -----------
# Merkle Tree
# -----------

# hash leaf
leaf_version = 192 # 0xc0
script = '206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac' # OP_PUSHBYTES_32 6d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0 OP_CHECKSIG
leaf_hash = tagged_hash("TapLeaf", field(dechex(leaf_version), 1) + serialize_script(script))
puts 'leaf_hash: ' + leaf_hash
#=> 858dfe26a3dd48a2c1fcee1d631f0aadf6a61135fc51f75758e945bca534ef16

# merkle root
merkle_root = leaf_hash
puts 'merkle_root: ' + merkle_root
# ----------------
# Tweak Public Key
# ----------------

# create a hash from the public key and merkle root - this will be used to tweak the public key
tweak = tagged_hash("TapTweak", internal_pubkey + merkle_root) 
puts 'tweak: ' + tweak
#=> 479785dd89a6441dbe00c7661865a0cc68672e8021f4547ac7f89ac26ac049f2

# tweak the public key
t = int(tweak) # convert to integer (so it's like a private key) (check this is less than curve order)
internal_pubkey_point = lift_x(internal_pubkey)
tweaked_pubkey_point = add(internal_pubkey_point, multiply(t, $G)) # (check y is even)
tweaked_pubkey = bytes(tweaked_pubkey_point[:x])
puts 'tweaked_pubkey: ' + tweaked_pubkey
#=> f3778defe5173a9bf7169575116224f961c03c725c0e98b8da8f15df29194b80

# convert to scriptpubkey
scriptpubkey = '51' + '20' + tweaked_pubkey
puts 'scriptpubkey: ' + scriptpubkey
#=> 5120f3778defe5173a9bf7169575116224f961c03c725c0e98b8da8f15df29194b80

# Generate Taproot Address
pubkey_hash = scriptpubkey[4..-1]
puts 'pubkey_hash: ' + pubkey_hash
address = encode_taproot_address(pubkey_hash)
puts 'address: ' + address

# =====
# Spend
# =====

# -------------
# Control Block
# -------------
# <control byte with leaf version and parity bit> <internal pubkey> <leaves/branches required to calculate merkle root>

# note: all leaf_versions are 192
control_byte = calculate_control_byte(192, tweaked_pubkey_point)

# control block (no branches or leaves are needed to build the merkle root - the hash of the script is the merkle root)
control_block = control_byte + internal_pubkey
#=> c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329

# -------------------
# Signature Algorithm
# -------------------

# unsigned raw tx:
#
# 020000000001013cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff01983a0000000000001600140de745dc58d8e62e6f47bde30cd5804a82016f9e0000000000

hash_type = 1 # SIGHASH_ALL
hash_type_byte = field(dechex(hash_type), 1)

ext_flag = 1 # Use ext_flag = 1 to indicate we are spending using tapscript (i.e. a script path spend of a taproot output)
annex_present = 0 # 1 = true, 0 = false
spend_type = field(dechex((ext_flag * 2) + annex_present), 1)

version = '02000000'
locktime = '00000000'

# hash_type & 0x80 != SIGHASH_ANYONECANPAY
prevouts = '3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d1'+'00000000'
amounts = reversebytes(field(dechex('20000'), 8))
sequences = 'ffffffff'
scriptpubkeys = serialize_script('5120f3778defe5173a9bf7169575116224f961c03c725c0e98b8da8f15df29194b80')

sha_prevouts = Digest::SHA256.hexdigest([prevouts].pack("H*"));           #=> fd9703aeae8f25e8734366f3be9b5e7ac2a56772d577c598cfa6e869c698f7eb
sha_amounts = Digest::SHA256.hexdigest([amounts].pack("H*"));             #=> ae9475d31b535bec000c9bfc7abc79b6a07db9eea2dd0e5066adddfb349bb53b
sha_sequences = Digest::SHA256.hexdigest([sequences].pack("H*"));         #=> ad95131bc0b799c0b1af477fb14fcf26a6a9f76079e48bf090acb7e8367bfd0e
sha_scriptpubkeys = Digest::SHA256.hexdigest([scriptpubkeys].pack("H*")); #=> ef0ffac40687f5fc2a58c5348cd6f17469c333d0f2782769e0c3f05e97062182

outputs = '983a000000000000' + serialize_script('00140de745dc58d8e62e6f47bde30cd5804a82016f9e')
sha_outputs = Digest::SHA256.hexdigest([outputs].pack("H*")); #=> 41c602530c3cfa80923771e080db8674c730480f9764290bc5b372ae28cf8dbc

input_outpoint = '3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d1'+'00000000'
input_amount = reversebytes(field(dechex('20000'), 8))
input_scriptpubkey = serialize_script('5120f3778defe5173a9bf7169575116224f961c03c725c0e98b8da8f15df29194b80') # always 32 bytes
input_sequence = 'ffffffff'

input_index = '00000000' # 4-byte vin of the input you're spending

sha_annex = '' # SHA256 of (compact_size(size of annex) || annex), where annex includes the mandatory 0x50 prefix

sha_single_output = ''


# common signature message
sigmsg = ''
sigmsg += hash_type_byte + version + locktime

# NOT SIGHASH_ANYONECANPAY (0x80)
if (hash_type & 0x80 == 0)
  sigmsg += sha_prevouts + sha_amounts + sha_scriptpubkeys + sha_sequences
end

# NOT SIGHASH_NONE (0x02/0x82) OR SIGHASH_SINGLE (0x03/0x83)
if (hash_type & 3 < 2)
  sigmsg += sha_outputs
end

sigmsg += spend_type

# NOT SIGHASH_ANYONECANPAY (0x80)
if (hash_type & 0x80 == 0)
  sigmsg += input_index

# SIGHASH_ANYONECANPAY (0x80)
else
  sigmsg += input_outpoint + input_amount + input_scriptpubkey + input_sequence
end

if (annex_present == 1)
  annex = ''
  sha_annex = Digest::SHA256.hexdigest([annex].pack("H*"))
  sigmsg += sha_annex
end

# SIGHASH_SINGLE
if (hash_type & 3 == 3)
  sigmsg += sha_single_output
end

# SigMsg extension (BIP 342)
if (ext_flag == 1)

  # <extension> = <tap leaf hash> <key version = 0x00> <codesep position = 0xffffffff>
  #   <tap leaf hash>    = the leaf hash of the script you're spending
  #   <key version>      = public key version (currently 0x00)
  #   <codesep position> = the opcode position of the last OP_CODESEPARATOR (0xffffffff if none)
  extension = leaf_hash + '00' + 'ffffffff'

  sigmsg += extension
#=> 010200000000000000fd9703aeae8f25e8734366f3be9b5e7ac2a56772d577c598cfa6e869c698f7ebae9475d31b535bec000c9bfc7abc79b6a07db9eea2dd0e5066adddfb349bb53bef0ffac40687f5fc2a58c5348cd6f17469c333d0f2782769e0c3f05e97062182ad95131bc0b799c0b1af477fb14fcf26a6a9f76079e48bf090acb7e8367bfd0e41c602530c3cfa80923771e080db8674c730480f9764290bc5b372ae28cf8dbc0200000000858dfe26a3dd48a2c1fcee1d631f0aadf6a61135fc51f75758e945bca534ef1600ffffffff
end

# sighash
sighash = tagged_hash("TapSighash", '00' + sigmsg) # don't forget the 0x00 prefix to the sigmsg
#=> 752453d473e511a0da2097d664d69fe5eb89d8d9d00eab924b42fc0801a980c9

# ---------
# Signature
# ---------

# signing data
private_key = '9b8de5d7f20a8ebb026a82babac3aa47a008debbfde5348962b2c46520bd5189'
message = sighash
aux_rand = '0000000000000000000000000000000000000000000000000000000000000000' # all signatures are created with an all-zero (0x0000...0000) BIP340 auxiliary randomness array.

# ----
# Sign
# ----

# convert private key to an integer
d0 = int(private_key)

# make sure private key is in valid range (greater than 0 and less than the number of points on the curve)
unless (1..$n-1).include?(d0)
  raise "private key must be in the range 1..n-1"
end

# calculate the public key point from the private key
public_key_point = multiply(d0) # multiply() checks for point at infinity

# negate the private key if the public key it creates doesn't have an even y value, else keep the private key the same
# note: due to the way the elliptic curve works, negate the private key will produce a public key with the same x coordinate, but the opposite y value
if public_key_point[:y] % 2 != 0
  d = $n - d0
else
  d = d0
end

# create a tagged hash of the auxiliary bytes
aux_rand_hash = tagged_hash("BIP0340/aux", aux_rand)

# first step toward creating the nonce is to XOR the private key with the hash of the auxiliary bytes
t = d ^ int(aux_rand_hash)

# create the nonce by hashing t (from the previous step) along with the public_key and message
k0 = int(tagged_hash("BIP0340/nonce", bytes(t) + bytes(public_key_point[:x]) + message)) % $n # public key is included in hash for "key-prefixed" schnorr signatures

# check that the nonce isn't zero
if k0 == 0
  raise "nonce must not be zero (this is almost impossible, but checking anyway)"
end

# use this nonce to get a point on the curve
random_point = multiply(k0) # multiply() checks for point at infinity

# negate the nonce used to create the random point if the public key it creates doesn't have an even y value
if random_point[:y] % 2 != 0
  k = $n - k0
  # note: due to the way the elliptic curve works, the inverse private key will produce an even y value
else
  k = k0
end

# create the challenge e value by hashing the random point with the public key and message
e = int(tagged_hash("BIP0340/challenge", bytes(random_point[:x]) + bytes(public_key_point[:x]) + message)) % $n

# r value is the x-coordinate of point R
r =  random_point[:x]

# s value: (k + e*d) mod n
s = (k + e * d) % $n # this is linear (whereas s in ECDSA is non-linear)

# signature is the r and s values converted to 32-byte hexadecimal string and concatenated
sig = bytes(r) + bytes(s)
#=> 01769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f

# witness (signature + hash_type byte)
signature = sig + hash_type_byte
#=> 01769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f01

# NOTE: If the hash_type_byte is not given (i.e. the signature is 64 instead of 64 bytes), the hash_type is assumed to be 0x00
# Why permit two signature lengths? By making the most common type of hash_type implicit, a byte can often be saved.

# -------
# Witness
# -------
# <script inputs> <script> <control block>

script_inputs = signature # CAUTION: The witness only contains data pushes, unlike the scriptSig.
script        = '206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac' # OP_PUSHBYTES_32 6d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0 OP_CHECKSIG
control_block = control_block

witness = 
  compact_size(3) + 
  compact_size(script_inputs.length / 2) + script_inputs + 
  compact_size(script.length / 2) + script + 
  compact_size(control_block.length / 2) + control_block

puts witness
#=> 034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329
