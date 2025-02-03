# -------------------------
# Elliptic Curve Parameters
# -------------------------
# these are the parameters for secp256k1, which is the same curve used in ECDSA
# note: setting these as $global variables so they're accessible from with the functions below (without having to pass them as arguments)

# y² = x³ + ax + b
$a = 0
$b = 7

# prime field
$p = 115792089237316195423570985008687907853269984665640564039457584007908834671663 #=> 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

# number of points on the curve we can hit ("order")
$n = 115792089237316195423570985008687907852837564279074904382605163141518161494337 #=> 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

# generator point (the starting point on the curve used for all calculations)
$G = {
  x: 55066263022277343669578718895168534326250603453777594175500187360389116729240, #=> 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
  y: 32670510020758816978083085130507043184471273380659243275938904335757337482424, #=> 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
}

# --------------------------
# Elliptic Curve Mathematics
# --------------------------

# Modular Inverse: Ruby doesn't have a built-in modinv function
def inverse(a, m = $p)
  m_orig = m         # store original modulus
  a = a % m if a < 0 # make sure a is positive
  y_prev = 0
  y = 1
  while a > 1
    q = m / a

    y_before = y # store current value of y
    y = y_prev - q * y # calculate new value of y
    y_prev = y_before # set previous y value to the old y value

    a_before = a # store current value of a
    a = m % a # calculate new value of a
    m = a_before # set m to the old a value
  end
  return y % m_orig
end

# Double: add a point to itself
def double(point)
  # check for point at infinity (greatest common divisor between 2y and p isn't 1)
  if (((2 * point[:y]) % $p).gcd($p) != 1) # taken from BitcoinECDSA.php
    raise "Point at infinity."
  end

  # slope = (3x₁² + a) / 2y₁
  slope = ((3 * point[:x] ** 2 + $a) * inverse((2 * point[:y]), $p)) % $p # using inverse to help with division

  # x = slope² - 2x₁
  x = (slope ** 2 - (2 * point[:x])) % $p

  # y = slope * (x₁ - x) - y₁
  y = (slope * (point[:x] - x) - point[:y]) % $p

  # Return the new point¢ªº
  return { x: x, y: y }
end

# Add: add two points together
def add(point1, point2)
  # double if both points are the same
  if point1 == point2
    return double(point1)
  end

  # check for point at infinity (greatest common divisor between x1-x2 and p isn't 1)
  if ((point1[:x] - point2[:x]).gcd($p) != 1) # taken from BitcoinECDSA.php
    raise "Point at infinity."
  end

  # slope = (y₁ - y₂) / (x₁ - x₂)
  slope = ((point1[:y] - point2[:y]) * inverse(point1[:x] - point2[:x], $p)) % $p

  # x = slope² - x₁ - x₂
  x = (slope ** 2 - point1[:x] - point2[:x]) % $p

  # y = slope * (x₁ - x) - y₁
  y = ((slope * (point1[:x] - x)) - point1[:y]) % $p

  # Return the new point
  return { x: x, y: y }
end

# Multiply: use double and add operations to quickly multiply a point by an integer value (i.e. a private key)
def multiply(k, point = $G)
  # create a copy the initial starting point (for use in addition later on)
  current = point

  # convert integer to binary representation
  binary = k.to_s(2)

  # double and add algorithm for fast multiplication
  binary.split("").drop(1).each do |char| # from left to right, ignoring first binary character
    # 0 = double
    current = double(current)

    # 1 = double and add
    current = add(current, point) if char == "1"
  end

  # return the final point
  current
end

# ----------------
# BIP340 Functions (Schnorr Signatures)
# ----------------

# convert hexadecimal string of bytes to integer
def int(bytes)
  return bytes.to_i(16)
end

# convert integer to hexadecimal string of bytes
def bytes(int)
  return int.to_s(16).rjust(64, "0") # convert to hex and pad with zeros to make it 32 bytes (64 characters)
end

# hash some data using SHA256 with a tag prefix
def tagged_hash(tag, message)
  # create a hash of the tag first
  tag_hash = Digest::SHA256.hexdigest(tag) # hash the string directly

  # prefix the message with the tag hash (the tag_hash is prefixed twice so that the prefix is 64 bytes in total)
  preimage = [tag_hash + tag_hash + message].pack("H*") # also convert to byte sequence before hashing
  # puts "preimage", preimage

  # SHA256(tag_hash || tag_hash || message)
  result = Digest::SHA256.hexdigest(preimage);

  return result
end

# convert public key (x coordinate only) in to a point - lift_x() in BIP 340
def lift_x(public_key)
  x = int(public_key) # convert from x coordinate from hex to an integer
  y_sq = (x**3 + 7) % $p # use the elliptic curve equation (y² = x³ + ax + b) to work out the value of y from x
  y = y_sq.pow(($p+1)/4, $p) # secp256k1 is chosen in a special way so that the square root of y is y^((p+1)/4)

  # check that x coordinate is less than the field size
  if x >= $p
    raise "x value in public key is not a valid coordinate because it is not less than the elliptic curve field size"
  end

  # verify that the computed y value is the square root of y_sq (otherwise the public key was not a valid x coordinate on the curve)
  if (y**2) % $p != y_sq
    raise "public key is not a valid x coordinate on the curve"
  end

  # if the calculated y value is odd, negate it to get the even y value instead (for this x-coordinate)
  if y % 2 != 0
    y = $p - y
  end

  # public key point
  public_key_point = {x: x, y: y}

  return public_key_point
end

# ----------------
# BIP341 Functions (Taproot)
# ----------------

# calculate control byte from leaf version and parity of tweaked public key
def calculate_control_byte(leaf_version, tweaked_pubkey_point)
	
	# set parity bit based on whether y is even or odd
	if (tweaked_pubkey_point[:y] % 2 == 0)
		parity_bit = 0 # y is even
	else
		parity_bit = 1 # y is odd
	end
  
  # Why is it necessary to reveal a bit in a script path spend and check that it matches the parity of the Y coordinate of Q?
  # The parity of the Y coordinate is necessary to lift the X coordinate q to a unique point. While this is not strictly necessary for verifying the taproot commitment as described above, it is necessary to allow batch verification. Alternatively, Q could be forced to have an even Y coordinate, but that would require retrying with different internal public keys (or different messages) until Q has that property. There is no downside to adding the parity bit because otherwise the control block bit would be unused.
	
	# calculate control byte
	control_byte = field(dechex(leaf_version + parity_bit), 1)
	
	return control_byte
end

# -----------------
# General Functions
# -----------------

# convert decimal number to hexadecimal
def dechex(dec)
  return dec.to_i.to_s(16)
end

# add padding to create a fixed-size field (e.g. 4 => 00000004)
def field(field, size=4)
  return field.to_s.rjust(size*2, '0')
end

# swap endianness
def reversebytes(hex)
  return hex.to_s.scan(/../).reverse.join
end

# get length of bytes in compact size structure
def compact_size(i)
  if (i <= 252)
    result = field(dechex(i), 1)
  elsif (i > 252 && i <= 65535)
    result = 'fd' + field(dechex(i), 2)
  elsif (i > 65535  && i <= 4294967295)
    result = 'fe' + field(dechex(i), 4)
  elsif (i > 4294967295 && i <= 18446744073709551615)
    result = 'ff' + field(dechex(i), 8)
  end

  return result
end

# add compact size field to start of scriptpubkey
def serialize_script(script)
  # get length of script as number of bytes
  length = script.length / 2
  
  # return script with compact size prepended
  return compact_size(length) + script
end

# Base58 encoding alphabet
ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def base58(hex_string)
  int_val = hex_string.to_i(16)
  base58_str = ""
  
  while int_val > 0
    int_val, remainder = int_val.divmod(58)
    base58_str = ALPHABET[remainder] + base58_str
  end
  
  # Add leading '1' characters for leading zero bytes
  hex_string.scan(/^00+/).first&.chars&.each { base58_str = '1' + base58_str }
  
  base58_str
end