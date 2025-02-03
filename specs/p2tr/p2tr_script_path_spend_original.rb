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

# merkle root
merkle_root = ""

# ----------------
# Tweak Public Key
# ----------------

# create a hash from the public key and merkle root - this will be used to tweak the public key
tweak = tagged_hash("TapTweak", internal_pubkey + merkle_root)
#=> 8dc8b9030225e044083511759b58328b46dffcc78b920b4b97169f9d7b43d3b5

# tweak the public key
t = int(tweak) # convert to integer (so it's like a private key) (check this is less than curve order)
internal_pubkey_point = lift_x(internal_pubkey)
tweaked_pubkey_point = add(internal_pubkey_point, multiply(t, $G)) # (check y is even)
tweaked_pubkey = bytes(tweaked_pubkey_point[:x])
#=> 0f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667
puts 'tweaked_pubkey: ' + tweaked_pubkey

# convert to scriptpubkey
scriptpubkey = '51' + '20' + tweaked_pubkey
#=> 51200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667
puts 'scriptpubkey: ' + scriptpubkey

# Generate Taproot Address
pubkey_hash = scriptpubkey[4..-1]
address = encode_taproot_address(pubkey_hash)
puts 'address: ' + address

# =====
# Spend
# =====

# -------------------
# Signature Algorithm
# -------------------

hash_type = 1 # SIGHASH_ALL
hash_type_byte = field(dechex(hash_type), 1) # specific hash type being used for this input (1 = SIGHASH_ALL)

ext_flag = 0
annex_present = 0 # 1 = true, 0 = false
spend_type = field(dechex((ext_flag * 2) + annex_present), 1)

# unsigned raw tx:
#
# 02000000000101ec9016580d98a93909faf9d2f431e74f781b438d81372bb6aab4db67725c11a70000000000ffffffff0110270000000000001600144e44ca792ce545acba99d41304460dd1f53be3840000000000

version = '02000000'
locktime = '00000000'

prevouts = 'ec9016580d98a93909faf9d2f431e74f781b438d81372bb6aab4db67725c11a7'+'00000000' # txid and amount are in little-endian
amounts = reversebytes(field(dechex('20000'), 8))
sequences = 'ffffffff'
scriptpubkeys = serialize_script('51200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667')

sha_prevouts = Digest::SHA256.hexdigest([prevouts].pack("H*"));           #=> eaff979f4771d11a857e48550a28c4d3503cf2a966182c94010fd21d5b700700
sha_amounts = Digest::SHA256.hexdigest([amounts].pack("H*"));             #=> ae9475d31b535bec000c9bfc7abc79b6a07db9eea2dd0e5066adddfb349bb53b
sha_sequences = Digest::SHA256.hexdigest([sequences].pack("H*"));         #=> ad95131bc0b799c0b1af477fb14fcf26a6a9f76079e48bf090acb7e8367bfd0e
sha_scriptpubkeys = Digest::SHA256.hexdigest([scriptpubkeys].pack("H*")); #=> 4cd686f794463476c6fc24b4a43e0abc7b58a0ea78a998d2be39cdb73f8d9cc2

outputs = '1027000000000000' + serialize_script('00144e44ca792ce545acba99d41304460dd1f53be384') # amount + scriptpubkey
sha_outputs = Digest::SHA256.hexdigest([outputs].pack("H*")); #=> c3a3f98ac2310126a614269e5715b0cabf38ce62232dd9ed8a878bdc0addea75

input_index = '00000000' # 4-byte vin of the input you're spending

sha_annex = ''

sha_single_output = ''

# signature message
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

sigmsg += sha_annex

# SIGHASH_SINGLE
if (hash_type & 3 == 3)
  sigmsg += sha_single_output
end

#=> 010200000000000000eaff979f4771d11a857e48550a28c4d3503cf2a966182c94010fd21d5b700700ae9475d31b535bec000c9bfc7abc79b6a07db9eea2dd0e5066adddfb349bb53b4cd686f794463476c6fc24b4a43e0abc7b58a0ea78a998d2be39cdb73f8d9cc2ad95131bc0b799c0b1af477fb14fcf26a6a9f76079e48bf090acb7e8367bfd0ec3a3f98ac2310126a614269e5715b0cabf38ce62232dd9ed8a878bdc0addea750000000000

# sighash epoch
epoch = '00'

# sighash
sighash = tagged_hash("TapSighash", epoch + sigmsg) # don't forget the 0x00 prefix to the sigmsg
#=> a7b390196945d71549a2454f0185ece1b47c56873cf41789d78926852c355132


# -----------------
# Tweak Private Key
# -----------------

# original data from before
internal_pubkey = '924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329'
tweak = '8dc8b9030225e044083511759b58328b46dffcc78b920b4b97169f9d7b43d3b5'
private_key = '55d7c5a9ce3d2b15a62434d01205f3e59077d51316f5c20628b3a4b8b2a76f4c'

# convert private key to the public key point so we can check if it creates an even y value
private_key_int = int(private_key) #=> 38827828470485795394567956987183954348973858899545806359243020977513867734860
private_key_to_public_key = multiply(private_key_int)
# {:x=>66172109705071441823295681989107852967180089637640153745774876919271983297321, :y=>48613218598235331436749946747294004934275959149063298181052452063566809595043}
# x = 924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329 (same as internal public key)

# negate the private key if y is odd
if private_key_to_public_key[:y] % 2 == 1
  private_key_int_negated = $n - private_key_int #=> 76964260766830400029003028021503953503863705379529098023362142164004293759477
else
  private_key_int_negated = private_key_int
end

tweaked_privkey_int = (private_key_int_negated + int(tweak)) % $n
tweaked_privkey = bytes(tweaked_privkey_int)
#=> 37f0f35933e8b52e6210dca589523ea5b66827b4749c49456e62fae4c89c6469

# ----
# Sign
# ----

# signing data
private_key = tweaked_privkey
message = sighash
aux_rand = '0000000000000000000000000000000000000000000000000000000000000000'

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
#=> b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae

# -------
# Witness
# -------

# witness (signature + hash_type byte)
witness = sig + hash_type_byte

puts witness
#=> b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae01
