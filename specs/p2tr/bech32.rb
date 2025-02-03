CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
BECH32M_CONST = 0x2bc830a3

def bech32_polymod(values)
  generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
  chk = 1
  values.each do |v|
    top = chk >> 25
    chk = (chk & 0x1ffffff) << 5 ^ v
    5.times do |i|
      chk ^= ((top >> i) & 1) == 1 ? generator[i] : 0
    end
  end
  chk
end

def bech32_hrp_expand(hrp)
  expand1 = hrp.each_byte.map { |b| b >> 5 }
  expand2 = hrp.each_byte.map { |b| b & 31 }
  expand1 + [0] + expand2
end

def convertbits(data, frombits, tobits, pad=true)
  acc = 0
  bits = 0
  ret = []
  maxv = (1 << tobits) - 1
  max_acc = (1 << (frombits + tobits - 1)) - 1
  data.each do |value|
    if value < 0 || (value >> frombits) != 0
      return nil
    end
    acc = ((acc << frombits) | value) & max_acc
    bits += frombits
    while bits >= tobits
      bits -= tobits
      ret << ((acc >> bits) & maxv)
    end
  end
  if pad
    if bits > 0
      ret << ((acc << (tobits - bits)) & maxv)
    end
  elsif bits >= frombits || ((acc << (tobits - bits)) & maxv) != 0
    return nil
  end
  ret
end

def bech32_create_checksum(hrp, data)
  values = bech32_hrp_expand(hrp) + data
  polymod = bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ BECH32M_CONST
  6.times.map { |i| (polymod >> 5 * (5 - i)) & 31 }
end

def bech32_encode(hrp, data)
  combined = data + bech32_create_checksum(hrp, data)
  "#{hrp}1#{combined.map { |i| CHARSET[i] }.join}"
end

def encode_taproot_address(pubkey_hex)
  # Convert pubkey to bytes array
  pubkey_bytes = [pubkey_hex].pack('H*').bytes
  
  # Convert to 5-bit words
  words = convertbits(pubkey_bytes, 8, 5, true)
  
  # Encode with bech32m
  bech32_encode("bc", [1] + words)
#   bech32_encode("tb", [1] + words)
  # bech32_encode("bcrt", [1] + words)
end